import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { attachFingerprintToUser, getUserIdByFingerprintId, creditWallet, addOperation } from '../store.js';

const router = express.Router();

// Enroll a fingerprint for a logged-in user.
router.post('/enroll', (req, res) => {
  const { userId, deviceModel } = req.body;
  if (!userId) return res.status(400).json({ code: 'INVALID_INPUT', message: 'userId is required' });
  const fingerprintId = uuidv4();
  attachFingerprintToUser(fingerprintId, userId, deviceModel ?? 'ZK9500');
  return res.status(201).json({ fingerprintId, message: 'Fingerprint enrollment started. Complete enrollment with the ZK device service.' });
});

// Confirm device authentication for a payment intent.
router.post('/authenticate', (req, res) => {
  const { paymentIntentId, fingerprintId, matched } = req.body;
  if (!paymentIntentId || !fingerprintId) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'paymentIntentId and fingerprintId are required' });
  }
  if (!global.paymentIntents || !global.paymentIntents.has(paymentIntentId)) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'Payment intent not found' });
  }
  const intent = global.paymentIntents.get(paymentIntentId);
  if (!intent) {
    return res.status(404).json({ code: 'NOT_FOUND', message: 'Payment intent not found' });
  }
  if (!matched) {
    intent.status = 'FAILED';
    return res.status(401).json({ success: false, status: intent.status, message: 'Fingerprint not matched' });
  }

  const userId = getUserIdByFingerprintId(fingerprintId);
  if (!userId || userId !== intent.userId) {
    intent.status = 'FAILED';
    return res.status(401).json({ success: false, status: intent.status, message: 'Fingerprint does not belong to the payment user' });
  }

  if (intent.state !== 'SETTLED') {
    creditWallet(intent.userId, intent.amountMinor);
    addOperation({
      userId: intent.userId,
      type: 'topup',
      description: `Fingerprint payment completed for ${intent.orderReference}`,
      amountMinor: intent.amountMinor,
      relatedId: paymentIntentId,
    });
    intent.state = 'SETTLED';
  }
  intent.status = 'COMPLETED';

  return res.json({
    success: true,
    status: intent.status,
    orderReference: intent.orderReference,
    paymentDevice: intent.paymentDevice,
  });
});

export default router;
