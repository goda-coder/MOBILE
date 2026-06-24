import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { createUser, findUserByEmail, findUserByPhone, findUserByName, getUserById, addRefreshToken, getUserIdByRefreshToken, revokeRefreshToken, getUserIdByFingerprintId } from '../store.js';

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

router.post('/logout', (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) revokeRefreshToken(refreshToken);
  return res.status(204).send();
});

export default router;
