import * as paymentService from '../services/paymentService.js';

export const initiate = async (req, res) => { 
  try {
    const { merchant_id, target_user_id, amount } = req.body;

    if (!merchant_id || !target_user_id || amount == null) {
      return res.status(400).json({
        code: 'INVALID_INPUT',
        message: 'merchant_id, target_user_id, and amount are required',
      });
    }

    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        code: 'INVALID_AMOUNT',
        message: 'amount must be a positive number',
      });
    }

    const transaction = await paymentService.initiatePayment({
      merchantId: merchant_id,
      targetUserId: target_user_id, 
      amountMinor: amount, 
    });

    return res.status(201).json({
      transaction_id: transaction.id || transaction.transaction_id, 
      status: transaction.status,
    });
  } catch (err) {
    const status = err.status || err.statusCode || 500;
    return res.status(status).json({
      code: err.code || 'INTERNAL_ERROR',
      message: err.message,
    });
  }
};

export const confirm = async (req, res) => {
  try {
    const { transaction_id, verification_token } = req.body;

    if (!transaction_id || !verification_token) {
      return res.status(400).json({
        code: 'INVALID_INPUT',
        message: 'transaction_id and verification_token are required',
      });
    }

    const result = await paymentService.confirmPayment({
      transactionId: transaction_id,
      verificationToken: verification_token,
    });

    return res.status(200).json(result);
  } catch (err) {
    // دعم status أو statusCode
    const status = err.status || err.statusCode || 500;
    return res.status(status).json({
      code: err.code || 'INTERNAL_ERROR',
      message: err.message,
    });
  }
};