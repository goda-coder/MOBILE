import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { TRANSFER_LIMITS } from './config.js';
import { computeLimits, checkTransferLimits as serviceCheck } from './services/transferLimitService.js';

const PIN_SALT_ROUNDS = 10;

const users = new Map();
const refreshTokens = new Map();
const wallets = new Map();
const fingerprints = new Map();
const operations = new Map();
const chats = new Map();
const kycRequests = new Map();
const validRoles = new Set(['customer', 'merchant', 'admin']);

const normalizeKey = (value) => typeof value === 'string' ? value.trim().toLowerCase() : '';

const findUserByEmail = (email) => {
  const normalized = normalizeKey(email);
  return [...users.values()].find((user) => normalizeKey(user.email) === normalized);
};
const findUserByPhone = (phone) => {
  const normalized = normalizeKey(phone).replace(/\s+/g, '');
  return [...users.values()].find((user) => normalizeKey(user.phoneNumber).replace(/\s+/g, '') === normalized);
};
const findUserByName = (fullName) => {
  const normalized = normalizeKey(fullName);
  return [...users.values()].find((user) => normalizeKey(user.fullName) === normalized);
};
const findUserByWalletId = (walletId) => {
  const entry = [...wallets.entries()].find(([, wallet]) => wallet.walletId === walletId);
  return entry ? users.get(entry[0]) : undefined;
};

const createUser = ({ fullName, email, phoneNumber, password, role = 'customer' }) => {
  if (findUserByEmail(email)) return null;
  if (findUserByPhone(phoneNumber)) return null;
  if (findUserByName(fullName)) return null;
  const userId = uuidv4();
  const passwordHash = bcrypt.hashSync(password, 10);
  const normalizedRole = validRoles.has(role.toLowerCase()) ? role.toLowerCase() : 'customer';
  const user = { userId, fullName, email, phoneNumber, passwordHash, role: normalizedRole };
  users.set(userId, user);
  wallets.set(userId, {
    walletId: uuidv4(),
    balanceMinor: 100000,
    currency: 'EGP',
    isKycVerified: false,
    kycStatus: 'None',
  });
  return user;
};

const getUserById = (userId) => users.get(userId);
const addRefreshToken = (userId, refreshToken) => refreshTokens.set(refreshToken, userId);
const getUserIdByRefreshToken = (token) => refreshTokens.get(token);
const revokeRefreshToken = (token) => refreshTokens.delete(token);
const getWallet = (userId) => wallets.get(userId);

const addOperation = ({ userId, type, description, amountMinor, currency = 'EGP', relatedId }) => {
  if (!operations.has(userId)) operations.set(userId, []);
  const op = {
    id: uuidv4(),
    type,
    description,
    amountMinor: amountMinor ?? 0,
    currency,
    relatedId: relatedId ?? null,
    createdAt: new Date().toISOString(),
  };
  operations.get(userId).push(op);
  return op;
};

const getWalletTransactions = (userId, skip = 0, take = 25) => {
  const list = operations.get(userId) ?? [];
  const filtered = list.filter((op) => ['transfer_in', 'transfer_out', 'topup', 'refund'].includes(op.type));
  return filtered.slice(skip, skip + take);
};

const getOperations = (userId, skip = 0, take = 50) => {
  const list = operations.get(userId) ?? [];
  return list.slice(skip, skip + take);
};

const addChatMessage = ({ userId, senderId, senderRole, content }) => {
  if (!chats.has(userId)) chats.set(userId, []);
  const message = {
    id: uuidv4(),
    userId,
    senderId,
    senderRole,
    content,
    createdAt: new Date().toISOString(),
  };
  chats.get(userId).push(message);
  return message;
};

const getChatMessages = (userId) => chats.get(userId) ?? [];
const getChatConversations = () => {
  return [...chats.entries()].map(([userId, messages]) => ({
    userId,
    lastMessage: messages[messages.length - 1],
    messageCount: messages.length,
  }));
};

const transactions = new Map();

// --- Concurrency lock (promise-chain based, no race window) ---
let _lockQueue = Promise.resolve();

const _withLock = async (fn) => {
  let release;
  const wait = new Promise((resolve) => { release = resolve; });
  const prev = _lockQueue;
  _lockQueue = _lockQueue.then(() => wait);
  await prev;
  try {
    return await fn();
  } finally {
    release();
  }
};

const createTransaction = ({ merchantId, targetUserId, amount }) => {
  const id = uuidv4();
  const tx = { id, merchantId, targetUserId, amount, status: 'PENDING', createdAt: new Date().toISOString(), completedAt: null };
  transactions.set(id, tx);
  return tx;
};

const getTransaction = (id) => transactions.get(id);

const updateTransactionStatus = (id, status) => {
  const tx = transactions.get(id);
  if (!tx) return null;
  tx.status = status;
  if (status === 'SUCCESS' || status === 'FAILED') tx.completedAt = new Date().toISOString();
  return tx;
};

// -- Transfer limits (data storage only; logic in config.js + services/transferLimitService.js) --

const transferLimits = new Map(); // Map<userId, {dailyUsed, monthlyUsed, dailyResetAt, monthlyResetAt}>

const _getTodayReset = () => {
  const now = new Date();
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);
  return tomorrow.toISOString();
};

/**
 * Returns a new Date exactly one calendar month after `date`, clamping
 * the day to the last day of the target month when necessary (e.g.
 * Jan 31 -> Feb 28/29, March 31 -> April 30).
 */
const _addCalendarMonth = (date) => {
  const year = date.getFullYear();
  const month = date.getMonth(); // 0-indexed
  const day = date.getDate();

  // Target month
  let targetMonth = month + 1;
  let targetYear = year;
  if (targetMonth > 11) {
    targetMonth = 0;
    targetYear += 1;
  }

  // Clamp day to the last day of the target month
  const lastDay = new Date(targetYear, targetMonth + 1, 0).getDate();
  const clampedDay = Math.min(day, lastDay);

  const result = new Date(targetYear, targetMonth, clampedDay);
  result.setHours(0, 0, 0, 0);
  return result;
};

const _ensureLimitsRecord = (userId) => {
  if (!transferLimits.has(userId)) {
    const now = new Date();
    transferLimits.set(userId, {
      dailyUsed: 0,
      monthlyUsed: 0,
      dailyResetAt: _getTodayReset(),
      monthlyCycleStart: now.toISOString(),
      monthlyResetAt: _addCalendarMonth(now).toISOString(),
    });
  }
  const rec = transferLimits.get(userId);
  const nowMs = Date.now();
  if (new Date(rec.dailyResetAt).getTime() <= nowMs) {
    rec.dailyUsed = 0;
    rec.dailyResetAt = _getTodayReset();
  }
  if (new Date(rec.monthlyResetAt).getTime() <= nowMs) {
    rec.monthlyUsed = 0;
    const cycleStart = new Date();
    rec.monthlyCycleStart = cycleStart.toISOString();
    rec.monthlyResetAt = _addCalendarMonth(cycleStart).toISOString();
  }
  return rec;
};

const getTransferLimits = (userId) => {
  const rec = _ensureLimitsRecord(userId);
  return computeLimits(rec);
};

const checkTransferLimits = (userId, amountMinor) => {
  const rec = _ensureLimitsRecord(userId);
  return serviceCheck(rec, amountMinor);
};

const recordTransfer = (userId, amountMinor) => {
  const rec = _ensureLimitsRecord(userId);
  rec.dailyUsed += amountMinor;
  rec.monthlyUsed += amountMinor;
};

// -- Password change & brute-force protection ------------------------
const passwordChangeAttempts = new Map();
const pinResetAttempts = new Map();

const MAX_PASSWORD_CHANGE_ATTEMPTS = 5;
const PASSWORD_CHANGE_LOCKOUT_MIN = 15;
const MAX_PIN_RESET_ATTEMPTS = 5;
const PIN_RESET_LOCKOUT_MIN = 15;

function _isLocked(attemptsMap, userId, maxAttempts, lockoutMin) {
  const record = attemptsMap.get(userId);
  if (!record) return false;
  if (record.lockedUntil && Date.now() < record.lockedUntil) return true;
  if (record.lockedUntil && Date.now() >= record.lockedUntil) {
    attemptsMap.delete(userId);
    return false;
  }
  return false;
}

function _recordAttempt(attemptsMap, userId, success, maxAttempts, lockoutMin) {
  if (success) {
    attemptsMap.delete(userId);
    return;
  }
  const record = attemptsMap.get(userId) || { count: 0, lockedUntil: null };
  record.count += 1;
  if (record.count >= maxAttempts) {
    record.lockedUntil = Date.now() + lockoutMin * 60 * 1000;
  }
  attemptsMap.set(userId, record);
}

const isPasswordChangeLocked = (userId) =>
  _isLocked(passwordChangeAttempts, userId, MAX_PASSWORD_CHANGE_ATTEMPTS, PASSWORD_CHANGE_LOCKOUT_MIN);

const recordPasswordChangeAttempt = (userId, success) =>
  _recordAttempt(passwordChangeAttempts, userId, success, MAX_PASSWORD_CHANGE_ATTEMPTS, PASSWORD_CHANGE_LOCKOUT_MIN);

const isPinResetLocked = (userId) =>
  _isLocked(pinResetAttempts, userId, MAX_PIN_RESET_ATTEMPTS, PIN_RESET_LOCKOUT_MIN);

const recordPinResetAttempt = (userId, success) =>
  _recordAttempt(pinResetAttempts, userId, success, MAX_PIN_RESET_ATTEMPTS, PIN_RESET_LOCKOUT_MIN);

const updatePassword = (userId, newPassword) => {
  const user = users.get(userId);
  if (!user) return false;
  user.passwordHash = bcrypt.hashSync(newPassword, 10);
  return true;
};

const updatePin = (userId, newPin) => {
  const user = users.get(userId);
  if (!user) return false;
  const hash = bcrypt.hashSync(newPin, PIN_SALT_ROUNDS);
  pinHashes.set(userId, hash);
  user.pinHash = hash;
  return true;
};

const revokeAllRefreshTokens = (userId) => {
  for (const [token, uid] of refreshTokens.entries()) {
    if (uid === userId) refreshTokens.delete(token);
  }
};

// -- PIN management ------------------------------------------------
const pinHashes = new Map();

const _getPinHash = (userId) => {
  const fromMap = pinHashes.get(userId);
  if (fromMap) return fromMap;
  const user = users.get(userId);
  return user?.pinHash || null;
};

const createPin = (userId, pin) => {
  const hash = bcrypt.hashSync(pin, PIN_SALT_ROUNDS);
  pinHashes.set(userId, hash);
  const user = users.get(userId);
  if (user) user.pinHash = hash;
  return true;
};

const verifyPin = (userId, pin) => {
  const hash = _getPinHash(userId);
  if (!hash) return false;
  return bcrypt.compareSync(pin, hash);
};

const hasPin = (userId) => _getPinHash(userId) !== null;

const atomicTransfer = async (fromUserId, toUserId, amountMinor) => {
  return _withLock(() => {
    const fromWallet = wallets.get(fromUserId);
    const toWallet = wallets.get(toUserId);
    if (!fromWallet || !toWallet) throw new Error('Wallet not found');
    if (fromWallet.balanceMinor < amountMinor) throw new Error('Insufficient funds');
    fromWallet.balanceMinor -= amountMinor;
    toWallet.balanceMinor += amountMinor;
    return { fromWallet, toWallet };
  });
};

const attachFingerprintToUser = (fingerprintId, userId, deviceModel = 'ZK9500') => {
  const record = {
    fingerprintId,
    userId,
    deviceModel,
    enrolledAt: new Date().toISOString(),
  };
  fingerprints.set(fingerprintId, record);
  return record;
};

const getUserIdByFingerprintId = (fingerprintId) => fingerprints.get(fingerprintId)?.userId;
const getFingerprintRecord = (fingerprintId) => fingerprints.get(fingerprintId);

const creditWallet = (userId, amountMinor) => {
  const wallet = wallets.get(userId);
  if (!wallet) return null;
  wallet.balanceMinor += amountMinor;
  return wallet;
};

const seedUsers = [
  { fullName: 'Admin User', email: 'admin@wallet.local', phoneNumber: '+201000000001', password: 'Admin1234!', role: 'admin' },
  { fullName: 'Merchant User', email: 'merchant@wallet.local', phoneNumber: '+201000000002', password: 'Merchant1234!', role: 'merchant' },
];
for (const user of seedUsers) {
  if (!findUserByEmail(user.email)) createUser(user);
}

// Rebuild pinHashes from any users that have a pinHash (survives restart)
for (const user of users.values()) {
  if (user.pinHash) pinHashes.set(user.userId, user.pinHash);
}

const createKycRequest = ({ userId, fullName, phoneNumber, documentType, status, matchPercentage, warnings, idFrontPath, idBackPath, selfiePath }) => {
  const id = uuidv4();
  const request = {
    id,
    userId,
    fullName: fullName ?? 'Unknown',
    phoneNumber: phoneNumber ?? 'Unknown',
    documentType,
    status,
    matchPercentage,
    warnings,
    idFrontPath: idFrontPath ?? null,
    idBackPath: idBackPath ?? null,
    selfiePath: selfiePath ?? null,
    submittedAt: new Date().toISOString(),
    decidedAt: null,
    decisionReason: null,
  };
  kycRequests.set(id, request);
  return request;
};

const getLatestKycRequest = (userId) => [...kycRequests.values()].filter((item) => item.userId === userId).pop();

const getKycStatus = (userId) => {
  const last = getLatestKycRequest(userId);
  if (!last) return { isVerified: false, status: 'None', matchPercentage: 0.0, warnings: [], submittedAt: null, decidedAt: null, decisionReason: null };
  return {
    isVerified: last.status === 'Verified',
    status: last.status,
    matchPercentage: last.matchPercentage,
    warnings: last.warnings,
    submittedAt: last.submittedAt,
    decidedAt: last.decidedAt,
    decisionReason: last.decisionReason,
  };
};

const isUserKycVerified = (userId) => getLatestKycRequest(userId)?.status === 'Verified';

const getPendingKyc = () => [...kycRequests.values()].filter((item) => item.status === 'Pending');
const updateKycRequest = (id, updates) => {
  const request = kycRequests.get(id);
  if (!request) return null;
  const updated = { ...request, ...updates, decidedAt: new Date().toISOString() };
  kycRequests.set(id, updated);
  return updated;
};

export {
  getTransferLimits,
  checkTransferLimits,
  recordTransfer,
  createUser,
  findUserByEmail,
  findUserByPhone,
  findUserByName,
  findUserByWalletId,
  getUserById,
  addRefreshToken,
  getUserIdByRefreshToken,
  revokeRefreshToken,
  revokeAllRefreshTokens,
  getWallet,
  addOperation,
  getWalletTransactions,
  getOperations,
  addChatMessage,
  getChatMessages,
  getChatConversations,
  createKycRequest,
  getLatestKycRequest,
  getKycStatus,
  isUserKycVerified,
  getPendingKyc,
  updateKycRequest,
  attachFingerprintToUser,
  getUserIdByFingerprintId,
  getFingerprintRecord,
  creditWallet,
  createTransaction,
  getTransaction,
  updateTransactionStatus,
  atomicTransfer,
  createPin,
  verifyPin,
  hasPin,
  updatePassword,
  updatePin,
  isPasswordChangeLocked,
  recordPasswordChangeAttempt,
  isPinResetLocked,
  recordPinResetAttempt,
};
