import { isUserKycVerified } from '../store.js';

export const requireKyc = (req, res, next) => {
  if (!isUserKycVerified(req.user.userId)) {
    return res.status(403).json({
      code: 'KYC_REQUIRED',
      message: 'KYC verification is required before performing this operation.',
    });
  }
  next();
};
