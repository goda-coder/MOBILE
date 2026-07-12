import express from 'express';
import { v4 as uuidv4 } from 'uuid';
// تم إضافة getTransaction للتحقق من حالة المعاملة الفعلية
import { addOperation, getTransaction } from '../store.js'; 
import * as paymentController from '../controllers/paymentController.js';
import { requireKyc } from '../middleware/requireKyc.js';

const router = express.Router();

router.post('/checkout', requireKyc, (req, res) => {
  const { amountMinor, method, firstName, lastName, email, phoneNumber, currency, walletPhoneNumber } = req.body;
  
  if (!amountMinor || !method || !firstName || !lastName || !email || !phoneNumber) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Required payment fields are missing' });
  }

  const allowedMethods = new Set(['card', 'wallet', 'fingerprint']);
  if (!allowedMethods.has(method)) {
    return res.status(400).json({ code: 'INVALID_METHOD', message: 'Payment method must be card, wallet, or fingerprint' });
  }

  if (method === 'fingerprint') {
    if (amountMinor < 1000) {
      return res.status(400).json({ code: 'INVALID_AMOUNT', message: 'Fingerprint payments must be at least 10 EGP (1000 minor units).' });
    }

    const intentId = uuidv4();
    const orderRef = 'FP-' + uuidv4().slice(0, 8).toUpperCase();
    if (!global.paymentIntents) global.paymentIntents = new Map();
    
    global.paymentIntents.set(intentId, {
      id: intentId,
      orderReference: orderRef,
      method: 'fingerprint',
      amountMinor,
      status: 'AWAITING_DEVICE_AUTH',
      state: 'PENDING',
      userId: req.user.userId,
      paymentDevice: 'ZK9500',
      paymentNote: 'Authenticate using ZK9500 fingerprint reader to complete this payment.',
      deviceAuthRequired: true,
    });
    
    addOperation({
      userId: req.user.userId,
      type: 'payment_intent',
      description: `Started fingerprint payment ${orderRef}`,
      amountMinor,
      relatedId: intentId,
    });

    return res.json({
      paymentIntentId: intentId,
      orderReference: orderRef,
      iframeUrl: null,
      walletRedirectUrl: null,
      paymentDevice: 'ZK9500',
      paymentNote: 'Authenticate using ZK9500 fingerprint reader to complete this payment.',
      deviceAuthRequired: true,
    });
  }

  return res.json({
    paymentIntentId: uuidv4(),
    orderReference: 'ORD-' + uuidv4().slice(0, 8).toUpperCase(),
    iframeUrl: method === 'card' ? `https://checkout.example.com/${uuidv4()}` : null,
    walletRedirectUrl: method === 'wallet' ? `walletapp://pay/${uuidv4()}` : null,
  });
});

router.get('/status/:paymentIntentId', (req, res) => {
  const { paymentIntentId } = req.params;
  if (!paymentIntentId) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'paymentIntentId is required' });
  }
  if (!global.paymentIntents || !global.paymentIntents.has(paymentIntentId)) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'Payment intent not found' });
  }
  const intent = global.paymentIntents.get(paymentIntentId);
  return res.json({
    paymentIntentId: intent.id,
    orderReference: intent.orderReference,
    method: intent.method,
    status: intent.status,
    deviceAuthRequired: intent.deviceAuthRequired ?? false,
    paymentDevice: intent.paymentDevice,
    paymentNote: intent.paymentNote,
  });
});

// --- المسارات الجديدة للربط بنظام البصمة والدفع الفوري ---

router.get('/transaction-status/:transactionId', (req, res) => {
  const { transactionId } = req.params;
  const tx = getTransaction(transactionId);
  if (!tx) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'Transaction not found' });
  }
  return res.json({
    transaction_id: tx.id,
    status: tx.status, 
    completed_at: tx.completedAt
  });
});

// 2. مسارات تهيئة وتأكيد الدفع
router.post('/initiate', requireKyc, paymentController.initiate);
router.post('/confirm', requireKyc, paymentController.confirm);

export default router;