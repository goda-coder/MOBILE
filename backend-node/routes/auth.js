import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { createUser, findUserByEmail, findUserByPhone, findUserByName, getUserById, addRefreshToken, getUserIdByRefreshToken, revokeRefreshToken, revokeAllRefreshTokens, getUserIdByFingerprintId, createPin, verifyPin, hasPin, updatePassword, updatePin, isPasswordChangeLocked, recordPasswordChangeAttempt, isPinResetLocked, recordPinResetAttempt } from '../store.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
const secret = "instashiled_on_the_top" || 'secret';
const accessExpiresIn = process.env.ACCESS_TOKEN_EXPIRES_IN || '1h';
const refreshExpiresIn = process.env.REFRESH_TOKEN_EXPIRES_IN || '7d';

const buildTokens = (user) => {
  const accessToken = jwt.sign({ sub: user.userId, role: user.role, email: user.email }, secret, { expiresIn: accessExpiresIn });
  const refreshToken = jwt.sign({ sub: user.userId }, secret, { expiresIn: refreshExpiresIn });
  addRefreshToken(user.userId, refreshToken);
  return { accessToken, refreshToken };
};

router.post('/login', (req, res) => {
  const { phoneNumber, password } = req.body;
  if (!phoneNumber || !password) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Phone number and password are required' });
  }
  const user = findUserByPhone(phoneNumber);
  if (!user || !bcrypt.compareSync(password, user.passwordHash)) {
    return res.status(401).json({ code: 'INVALID_CREDENTIALS', message: 'Phone number or password is incorrect' });
  }
  const tokens = buildTokens(user);
  return res.json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    role: user.role === 'admin' ? 'Admin' : user.role === 'merchant' ? 'Merchant' : 'Customer',
    phoneNumber: user.phoneNumber,
    email: user.email,
    userId: user.userId,
    fullName: user.fullName,
    hasPin: hasPin(user.userId),
  });
});

router.post('/register', (req, res) => {
  const { fullName, email, phoneNumber, password, role } = req.body;
  if (!fullName || !email || !phoneNumber || !password) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'All registration fields are required' });
  }
  const allowedRoles = new Set(['customer', 'merchant', 'admin']);
  const normalizedRole = typeof role === 'string' ? role.toLowerCase() : 'customer';
  if (!allowedRoles.has(normalizedRole)) {
    return res.status(400).json({ code: 'INVALID_ROLE', message: 'Role must be customer, merchant, or admin' });
  }
  if (findUserByEmail(email)) {
    return res.status(409).json({ code: 'USER_EXISTS', message: 'An account with this email already exists' });
  }
  if (findUserByPhone(phoneNumber)) {
    return res.status(409).json({ code: 'USER_EXISTS', message: 'An account with this phone number already exists' });
  }
  if (findUserByName(fullName)) {
    return res.status(409).json({ code: 'USER_EXISTS', message: 'An account with this full name already exists' });
  }
  const user = createUser({ fullName, email, phoneNumber, password, role: normalizedRole });
  if (!user) {
    return res.status(409).json({ code: 'USER_EXISTS', message: 'Unable to create user due to duplicate account data' });
  }
  const tokens = buildTokens(user);
  return res.status(201).json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    role: normalizedRole === 'admin' ? 'Admin' : normalizedRole === 'merchant' ? 'Merchant' : 'Customer',
    phoneNumber: user.phoneNumber,
    userId: user.userId,
    fullName: user.fullName,
    hasPin: false,
  });
});

router.post('/login-fingerprint', (req, res) => {
  const { fingerprintId, matched } = req.body;
  if (!fingerprintId) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'fingerprintId is required' });
  }
  if (!matched) {
    return res.status(401).json({ code: 'UNAUTHORIZED', message: 'Fingerprint was not matched' });
  }
  const userId = getUserIdByFingerprintId(fingerprintId);
  if (!userId) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'Fingerprint not registered' });
  }
  const user = getUserById(userId);
  if (!user) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'User not found for fingerprint' });
  }
  const tokens = buildTokens(user);
  return res.json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    role: user.role === 'admin' ? 'Admin' : user.role === 'merchant' ? 'Merchant' : 'Customer',
    phoneNumber: user.phoneNumber,
    userId: user.userId,
    fullName: user.fullName,
    hasPin: hasPin(user.userId),
  });
});

router.post('/refresh', (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Refresh token is required' });
  }
  const userId = getUserIdByRefreshToken(refreshToken);
  if (!userId) {
    return res.status(401).json({ code: 'INVALID_TOKEN', message: 'Refresh token is invalid' });
  }
  const user = getUserById(userId);
  if (!user) {
    return res.status(401).json({ code: 'INVALID_TOKEN', message: 'Refresh token is invalid' });
  }
  try {
    jwt.verify(refreshToken, secret);
    const tokens = buildTokens(user);
    return res.json({ accessToken: tokens.accessToken, refreshToken: tokens.refreshToken });
  } catch (error) {
    return res.status(401).json({ code: 'INVALID_TOKEN', message: 'Refresh token is invalid or expired' });
  }
});

router.post('/pin', authenticate, (req, res) => {
  const { pin } = req.body;
  if (!pin || pin.length !== 6 || !/^\d{6}$/.test(pin)) {
    return res.status(400).json({ code: 'INVALID_PIN', message: 'PIN must be exactly 6 digits.' });
  }
  const weakPins = ['000000', '111111', '222222', '333333', '444444', '555555', '666666', '777777', '888888', '999999', '123456', '654321', '123456789'];
  if (weakPins.includes(pin)) {
    return res.status(400).json({ code: 'WEAK_PIN', message: 'This PIN is too common. Please choose a different one.' });
  }
  createPin(req.user.userId, pin);
  return res.json({ success: true, hasPin: true });
});

router.post('/verify-pin', authenticate, (req, res) => {
  const { pin } = req.body;
  if (!pin || !/^\d{6}$/.test(pin)) {
    return res.status(400).json({ code: 'INVALID_PIN', message: 'PIN must be exactly 6 digits.' });
  }
  if (!hasPin(req.user.userId)) {
    return res.status(400).json({ code: 'NO_PIN', message: 'No PIN has been set yet.' });
  }
  if (!verifyPin(req.user.userId, pin)) {
    return res.status(403).json({ code: 'PIN_MISMATCH', message: 'PIN is incorrect.' });
  }
  return res.json({ success: true });
});

/* Verify current password (used in reset flows before allowing changes) */
router.post('/verify-password', authenticate, (req, res) => {
  const { currentPassword } = req.body;
  const userId = req.user.userId;

  if (!currentPassword) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Current password is required.' });
  }

  if (isPasswordChangeLocked(userId)) {
    return res.status(429).json({ code: 'TOO_MANY_ATTEMPTS', message: 'Too many attempts. Please try again later.' });
  }

  if (!bcrypt.compareSync(currentPassword, req.user.passwordHash)) {
    recordPasswordChangeAttempt(userId, false);
    return res.status(403).json({ code: 'INVALID_PASSWORD', message: 'Current password is incorrect.' });
  }

  recordPasswordChangeAttempt(userId, true);
  return res.json({ valid: true });
});

/* Change password – requires authentication */
router.post('/change-password', authenticate, (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const userId = req.user.userId;

  if (isPasswordChangeLocked(userId)) {
    return res.status(429).json({ code: 'TOO_MANY_ATTEMPTS', message: 'Too many attempts. Please try again later.' });
  }

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Current password and new password are required.' });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({ code: 'WEAK_PASSWORD', message: 'New password must be at least 8 characters.' });
  }

  if (!bcrypt.compareSync(currentPassword, req.user.passwordHash)) {
    recordPasswordChangeAttempt(userId, false);
    return res.status(403).json({ code: 'INVALID_PASSWORD', message: 'Current password is incorrect.' });
  }

  if (bcrypt.compareSync(newPassword, req.user.passwordHash)) {
    return res.status(400).json({ code: 'SAME_PASSWORD', message: 'New password must be different from the current password.' });
  }

  updatePassword(userId, newPassword);
  recordPasswordChangeAttempt(userId, true);
  revokeAllRefreshTokens(userId);

  return res.json({ success: true, message: 'Password updated successfully.' });
});

/* Reset Security PIN – requires current password verification */
router.post('/reset-pin', authenticate, (req, res) => {
  const { currentPassword, newPin } = req.body;
  const userId = req.user.userId;

  if (isPinResetLocked(userId)) {
    return res.status(429).json({ code: 'TOO_MANY_ATTEMPTS', message: 'Too many attempts. Please try again later.' });
  }

  if (!currentPassword || !newPin) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Current password and new PIN are required.' });
  }

  if (!bcrypt.compareSync(currentPassword, req.user.passwordHash)) {
    recordPinResetAttempt(userId, false);
    return res.status(403).json({ code: 'INVALID_PASSWORD', message: 'Current password is incorrect.' });
  }

  if (newPin.length !== 6 || !/^\d{6}$/.test(newPin)) {
    return res.status(400).json({ code: 'INVALID_PIN', message: 'PIN must be exactly 6 digits.' });
  }

  const weakPins = ['000000', '111111', '222222', '333333', '444444', '555555', '666666', '777777', '888888', '999999', '123456', '654321', '123456789'];
  if (weakPins.includes(newPin)) {
    return res.status(400).json({ code: 'WEAK_PIN', message: 'This PIN is too common. Please choose a different one.' });
  }

  if (verifyPin(userId, newPin)) {
    return res.status(400).json({ code: 'SAME_PIN', message: 'New PIN must be different from the current PIN.' });
  }

  updatePin(userId, newPin);
  recordPinResetAttempt(userId, true);

  return res.json({ success: true, message: 'PIN updated successfully.' });
});

router.post('/logout', (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) revokeRefreshToken(refreshToken);
  return res.status(204).send();
});

export default router;
