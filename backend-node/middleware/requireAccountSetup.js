import { hasPin, isUserKycVerified } from '../store.js';

export const requireAccountSetup = (req, res, next) => {
  if (req.user.role === 'admin') return next();
  if (!hasPin(req.user.userId)) {
    return res.status(403).json({
      code: 'ACCOUNT_LOCKED',
      message: 'Security PIN has not been created. Please set up your PIN first.',
    });
  }
  if (!isUserKycVerified(req.user.userId)) {
    return res.status(403).json({
      code: 'KYC_REQUIRED',
      message: 'KYC verification is required before performing this operation.',
    });
  }
  next();
};
