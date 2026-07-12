import express from 'express';
import { getWallet, findUserByEmail, findUserByPhone, findUserByWalletId } from '../store.js';
import { runFraudCheck } from '../middleware/fraudDetection.js';

const router = express.Router();

router.post('/check', async (req, res) => {
  const { recipientIdentifier, amountMinor, description } = req.body;
  if (!recipientIdentifier || !amountMinor) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'recipientIdentifier and amountMinor are required' });
  }

  const senderWallet = getWallet(req.user.userId);
  if (!senderWallet) {
    return res.status(404).json({ code: 'WALLET_NOT_FOUND', message: 'Sender wallet not found' });
  }
  if (senderWallet.balanceMinor < amountMinor) {
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

  const result = await runFraudCheck({
    senderUserId: req.user.userId,
    recipientUserId: recipient.userId,
    amountMinor,
    senderBalanceBefore: senderWallet.balanceMinor,
    recipientBalanceBefore: recipientWallet.balanceMinor,
  });

  return res.json(result);
});

export default router;
