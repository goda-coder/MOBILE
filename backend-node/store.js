import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

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
let transferLock = false;

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

const atomicTransfer = (fromUserId, toUserId, amountMinor) => {
  if (transferLock) throw new Error('Concurrent transfer detected');
  transferLock = true;
  try {
    const fromWallet = wallets.get(fromUserId);
    const toWallet = wallets.get(toUserId);
    if (!fromWallet || !toWallet) throw new Error('Wallet not found');
    if (fromWallet.balanceMinor < amountMinor) throw new Error('Insufficient funds');
    fromWallet.balanceMinor -= amountMinor;
    toWallet.balanceMinor += amountMinor;
    return { fromWallet, toWallet };
  } finally {
    transferLock = false;
  }
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
  createUser,
  findUserByEmail,
  findUserByPhone,
  findUserByName,
  findUserByWalletId,
  getUserById,
  addRefreshToken,
  getUserIdByRefreshToken,
  revokeRefreshToken,
  getWallet,
  addOperation,
  getWalletTransactions,
  getOperations,
  addChatMessage,
  getChatMessages,
  getChatConversations,
  createKycRequest,
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
};
