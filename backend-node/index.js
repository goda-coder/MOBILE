import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRouter from './routes/auth.js';
import walletRouter from './routes/wallet.js';
import paymentsRouter from './routes/payments.js';
import kycRouter from './routes/kyc.js';
import adminRouter from './routes/admin.js';
import fingerprintRouter from './routes/fingerprint.js';
import chatRouter from './routes/chat.js';
import { authenticate } from './middleware/auth.js';

dotenv.config();
const app = express();
const port = process.env.PORT || 8081;

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/v1/auth', authRouter);
app.use('/api/v1/wallet', authenticate, walletRouter);
app.use('/api/v1/payments', authenticate, paymentsRouter);
app.use('/api/v1/kyc', authenticate, kycRouter);
app.use('/api/v1/admin', authenticate, adminRouter);
app.use('/api/v1/fingerprint', authenticate, fingerprintRouter);
app.use('/api/v1/chat', authenticate, chatRouter);

app.get('/', (req, res) => res.send({ status: 'ok', version: '1.0.0' }));

app.listen(port, () => {
  console.log(`Wallet backend listening on http://localhost:${port}`);
});
