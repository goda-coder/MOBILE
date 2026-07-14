import express from 'express';
import { getWallet, addOperation, getWalletTransactions, getOperations, findUserByEmail, findUserByPhone, findUserByWalletId, creditWallet, getKycStatus, getTransferLimits, checkTransferLimits, recordTransfer, atomicTransfer } from '../store.js';
import { v4 as uuidv4 } from 'uuid';
import { runFraudCheck } from '../middleware/fraudDetection.js';
import { requireAccountSetup } from '../middleware/requireAccountSetup.js';

const router = express.Router();

router.get('/validate-recipient/:identifier', requireAccountSetup, (req, res) => {
  const { identifier } = req.params;
  const recipient = findUserByEmail(identifier) || findUserByPhone(identifier) || findUserByWalletId(identifier);
  if (!recipient) {
    return res.status(404).json({ code: 'RECIPIENT_NOT_FOUND', message: 'Recipient account not found' });
  }
  const kyc = getKycStatus(recipient.userId);
  if (kyc.status !== 'Verified') {
    return res.status(403).json({ code: 'RECIPIENT_KYC_NOT_VERIFIED', message: 'Recipient KYC not verified' });
  }
  return res.json({ fullName: recipient.fullName });
});

router.get('/transfer-limits', requireAccountSetup, (req, res) => {
  const limits = getTransferLimits(req.user.userId);
  return res.json(limits);
});

router.get('/summary', requireAccountSetup, (req, res) => {
  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  const kyc = getKycStatus(req.user.userId);
  return res.json({
    ...wallet,
    isKycVerified: kyc.isVerified,
    kycStatus: kyc.status,
  });
});

router.get('/transactions', requireAccountSetup, (req, res) => {
  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  const transactions = getWalletTransactions(req.user.userId).map((tx) => ({
    ...tx,
    kind: tx.type,
    status: 'Completed',
    reference: tx.relatedId ?? '',
  }));
  return res.json(transactions);
});

router.get('/report', requireAccountSetup, (req, res) => {
  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  const operations = getOperations(req.user.userId).map((op) => ({
    ...op,
    kind: op.type,
    reference: op.relatedId ?? '',
    status: 'Completed',
  }));
  return res.json({ wallet, operations });
});

router.get('/reports', requireAccountSetup, (req, res) => {
  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  const operations = getOperations(req.user.userId).map((op) => ({
    ...op,
    kind: op.type,
    reference: op.relatedId ?? '',
    status: 'Completed',
  }));
  return res.json({ wallet, operations });
});

router.post('/transfer', requireAccountSetup, async (req, res) => {
  const { recipientIdentifier, amountMinor, currency, reference, description } = req.body;
  if (!recipientIdentifier || !amountMinor || !reference) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'recipientIdentifier, amountMinor and reference are required' });
  }

  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  if (wallet.balanceMinor < amountMinor) {
    return res.status(400).json({ code: 'INSUFFICIENT_FUNDS', message: 'Not enough balance' });
  }

  const recipient = findUserByEmail(recipientIdentifier) || findUserByPhone(recipientIdentifier) || findUserByWalletId(recipientIdentifier);
  if (!recipient) {
    return res.status(404).json({ code: 'RECIPIENT_NOT_FOUND', message: 'Recipient account not found' });
  }
  const recipientWallet = getWallet(recipient.userId);
  if (!recipientWallet) {
    return res.status(404).json({ code: 'RECIPIENT_WALLET_NOT_FOUND', message: 'Recipient wallet not found' });
  }

  if (recipient.userId === req.user.userId) {
    return res.status(400).json({
      code: 'SELF_TRANSFER',
      message: 'You cannot transfer to your own account.',
    });
  }

  const limitCheck = checkTransferLimits(req.user.userId, amountMinor);
  if (!limitCheck.allowed) {
    return res.status(403).json({
      code: 'TRANSFER_LIMIT_EXCEEDED',
      message: limitCheck.limitType === 'daily'
        ? `Daily transfer limit exceeded. You can transfer up to ${(limitCheck.remaining / 100).toFixed(2)} EGP today.`
        : `Monthly transfer limit exceeded. You can transfer up to ${(limitCheck.remaining / 100).toFixed(2)} EGP this month.`,
      details: limitCheck,
    });
  }

  const fraudResult = await runFraudCheck({
    senderUserId: req.user.userId,
    recipientUserId: recipient.userId,
    amountMinor,
    senderBalanceBefore: wallet.balanceMinor,
    recipientBalanceBefore: recipientWallet.balanceMinor,
  });
  if (!fraudResult.passed) {
    return res.status(403).json({
      code: 'FRAUD_BLOCKED',
      message: 'Transaction blocked by fraud detection.',
      details: fraudResult,
    });
  }

  try {
    await atomicTransfer(req.user.userId, recipient.userId, amountMinor);
  } catch (transferErr) {
    return res.status(400).json({ code: 'TRANSFER_FAILED', message: transferErr.message });
  }
  recordTransfer(req.user.userId, amountMinor);

  addOperation({
    userId: req.user.userId,
    type: 'transfer_out',
    description: description || `Transfer to ${recipient.fullName}`,
    amountMinor,
    currency: currency || wallet.currency,
    relatedId: reference,
  });
  addOperation({
    userId: recipient.userId,
    type: 'transfer_in',
    description: description || `Received transfer from ${req.user.fullName}`,
    amountMinor,
    currency: currency || recipientWallet.currency,
    relatedId: reference,
  });

  return res.json({ transactionId: uuidv4(), newBalanceMinor: wallet.balanceMinor });
});

export default router;
