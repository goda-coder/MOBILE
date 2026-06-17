import express from 'express';
import { getWallet, addOperation, getWalletTransactions, getOperations, findUserByEmail, findUserByPhone, findUserByWalletId, creditWallet, getKycStatus, isUserKycVerified } from '../store.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

router.get('/summary', (req, res) => {
  const wallet = getWallet(req.user.userId);
  if (!wallet) return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Wallet not found' });
  const kyc = getKycStatus(req.user.userId);
  return res.json({
    ...wallet,
    isKycVerified: kyc.isVerified,
    kycStatus: kyc.status,
  });
});

router.get('/transactions', (req, res) => {
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

router.get('/report', (req, res) => {
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

router.get('/reports', (req, res) => {
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

router.post('/transfer', (req, res) => {
  const { recipientIdentifier, amountMinor, currency, reference, description } = req.body;
  if (!recipientIdentifier || !amountMinor || !reference) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'recipientIdentifier, amountMinor and reference are required' });
  }
  if (!isUserKycVerified(req.user.userId)) {
    return res.status(403).json({ code: 'KYC_REQUIRED', message: 'KYC verification is required before funds transfers.' });
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

  wallet.balanceMinor -= amountMinor;
  recipientWallet.balanceMinor += amountMinor;

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
