import jwt from 'jsonwebtoken';
import {
  createTransaction,
  getTransaction,
  updateTransactionStatus,
  atomicTransfer,
  findUserByPhone,
  addOperation,
} from '../store.js';
import { runFraudCheck } from '../middleware/fraudDetection.js';

const JWT_SECRET = "instashiled_on_the_top" || 'secret';

export const initiatePayment = ({ merchantId, targetUserId, amountMinor }) => { // استخدام amountMinor حسب الـ Documentation
  const merchant = findUserByPhone(merchantId);
  if (!merchant || merchant.role !== 'merchant') {
    const err = new Error('Merchant not found or invalid role');
    err.status = 404;
    err.code = 'MERCHANT_NOT_FOUND';
    throw err;
  }

  const targetUser = findUserByPhone(targetUserId);
  if (!targetUser) {
    const err = new Error('Target user not found with this phone number');
    err.status = 404;
    err.code = 'USER_NOT_FOUND';
    throw err;
  }

  const transaction = createTransaction({
    merchantId: merchant.userId,
    targetUserId: targetUser.userId,
    amount: amountMinor
  });

  addOperation({
    userId: merchant.userId,
    type: 'payment_initiated',
    description: `Payment initiated for amount ${amountMinor} to user ${targetUser.phoneNumber}`,
    amountMinor: amountMinor,
    relatedId: transaction.id,
  });

  return transaction;
};

export const confirmPayment = async ({ transactionId, verificationToken }) => {
  let decoded;
  try {
    decoded = jwt.verify(verificationToken, JWT_SECRET);
  } catch (err) {
    const error = new Error('Invalid verification token');
    error.status = 403;
    error.code = 'INVALID_VERIFICATION_TOKEN';
    throw error;
  }

  const tx = getTransaction(transactionId);
  if (!tx) {
    const err = new Error('Transaction not found');
    err.status = 404;
    err.code = 'TRANSACTION_NOT_FOUND';
    throw err;
  }

  if (tx.status !== 'PENDING') {
    const err = new Error('Transaction is not in PENDING state');
    err.status = 409;
    err.code = 'INVALID_STATE';
    throw err;
  }

  if (decoded.transaction_id !== transactionId) {
    updateTransactionStatus(transactionId, 'FAILED');
    const err = new Error('Transaction ID mismatch in verification token');
    err.status = 403;
    err.code = 'TOKEN_MISMATCH';
    throw err;
  }

  const tokenUser = findUserByPhone(decoded.user_id);

  if (!tokenUser || tokenUser.userId !== tx.targetUserId) {
    updateTransactionStatus(transactionId, 'FAILED');
    const err = new Error('Biometric mismatch: Fingerprint does not belong to the target user');
    err.status = 403;
    err.code = 'USER_MISMATCH';
    throw err;
  }

  const fraudResult = await runFraudCheck(tx);
  if (!fraudResult.passed) {
    updateTransactionStatus(transactionId, 'FAILED');
    const err = new Error(`Fraud detection blocked transaction: ${fraudResult.flags.join(', ')}`);
    err.status = 403;
    err.code = 'FRAUD_BLOCKED';
    throw err;
  }

  try {
    atomicTransfer(tx.targetUserId, tx.merchantId, tx.amount);
  } catch (transferErr) {
    updateTransactionStatus(transactionId, 'FAILED');
    const err = new Error(transferErr.message);
    err.status = 400;
    err.code = 'TRANSFER_FAILED';
    throw err;
  }

  const updatedTx = updateTransactionStatus(transactionId, 'SUCCESS');

  addOperation({
    userId: tx.targetUserId,
    type: 'transfer_out',
    description: `Biometric payment to merchant ${tx.merchantId}`,
    amountMinor: tx.amount,
    relatedId: transactionId,
  });

  addOperation({
    userId: tx.merchantId,
    type: 'transfer_in',
    description: `Biometric payment from user ${tx.targetUserId}`,
    amountMinor: tx.amount,
    relatedId: transactionId,
  });

  return {
    transaction_id: transactionId,
    status: 'SUCCESS',
    receipt: `RCP-${transactionId.slice(0, 8).toUpperCase()}`,
    completed_at: updatedTx.completedAt,
  };
};