import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import authRouter from './routes/auth.js';
import walletRouter from './routes/wallet.js';
import paymentsRouter from './routes/payments.js';
import kycRouter from './routes/kyc.js';
import adminRouter from './routes/admin.js';
import fingerprintRouter from './routes/fingerprint.js';
import fingerprintDeviceRouter from './routes/fingerprintRoutes.js';
import chatRouter from './routes/chat.js';
import fraudRouter from './routes/fraud.js';
import { authenticate } from './middleware/auth.js';
import { findUserByPhone, getUserById, getLatestKycRequest, getKycStatus } from './store.js';

dotenv.config();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = process.env.PORT || 8081;

app.set('trust proxy', 1);
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use('/api/fingerprint', fingerprintDeviceRouter);
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/wallet', authenticate, walletRouter);
app.use('/api/v1/payments', authenticate, paymentsRouter);
app.use('/api/payments', authenticate, paymentsRouter);
app.use('/api/v1/kyc', authenticate, kycRouter);
app.use('/api/v1/admin', authenticate, adminRouter);
app.use('/api/v1/fingerprint', authenticate, fingerprintRouter);
app.use('/api/v1/chat', authenticate, chatRouter);
app.use('/api/v1/fraud', authenticate, fraudRouter);

app.get('/api/v1/profile', authenticate, (req, res) => {
  const user = req.user;
  res.json({
    fullName: user.fullName,
    phoneNumber: user.phoneNumber,
    email: user.email,
    role: user.role === 'admin' ? 'Admin' : user.role === 'merchant' ? 'Merchant' : 'Customer',
    userId: user.userId,
  });
});

app.get('/api/v1/enrollment/lookup/:phoneNumber', (req, res) => {
  const { phoneNumber } = req.params;
  if (!phoneNumber) {
    return res.status(400).json({ found: false, message: 'Phone number is required' });
  }
  const user = findUserByPhone(phoneNumber);
  if (!user) {
    return res.status(404).json({ found: false, message: 'User not found' });
  }
  const kycStatus = getKycStatus(user.userId);
  const latestKyc = getLatestKycRequest(user.userId);
  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const idCardFaceUrl = latestKyc?.idFrontPath ? `${baseUrl}/uploads/kyc/${latestKyc.idFrontPath}` : null;
  const idCardBackUrl = latestKyc?.idBackPath ? `${baseUrl}/uploads/kyc/${latestKyc.idBackPath}` : null;
  return res.json({
    found: true,
    user: {
      id: user.userId,
      fullName: user.fullName,
      phoneNumber: user.phoneNumber,
      kycStatus: kycStatus.status,
    },
    idCardFaceUrl,
    idCardBackUrl,
  });
});

app.get('/', (req, res) => res.send({ status: 'ok', version: '1.0.0' }));

const host = process.env.HOST || '0.0.0.0';
app.listen(port, host, () => {
  console.log(`Wallet backend listening on http://${host}:${port}`);
});
