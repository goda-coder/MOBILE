import express from 'express';
import { getPendingKyc, updateKycRequest } from '../store.js';

const router = express.Router();

const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ code: 'FORBIDDEN', message: 'Admin access required' });
  }
  next();
};

router.use('/kyc', requireAdmin);

router.get('/kyc/pending', (req, res) => {
  const pending = getPendingKyc().map((item) => ({
    id: item.id,
    userId: item.userId,
    fullName: item.fullName || 'Unknown',
    phoneNumber: item.phoneNumber || 'Unknown',
    matchPercentage: item.matchPercentage,
    submittedAt: item.submittedAt,
    warnings: item.warnings,
    idFrontUrl: item.idFrontPath ? `/uploads/kyc/${item.idFrontPath}` : null,
    idBackUrl: item.idBackPath ? `/uploads/kyc/${item.idBackPath}` : null,
    selfieUrl: item.selfiePath ? `/uploads/kyc/${item.selfiePath}` : null,
  }));
  return res.json(pending);
});

router.post('/kyc/:id/approve', (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  const updated = updateKycRequest(id, { status: 'Verified', decisionReason: reason });
  if (!updated) return res.status(404).json({ code: 'KYCREQ_NOT_FOUND', message: 'KYC request not found' });
  return res.status(204).send();
});

router.post('/kyc/:id/reject', (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  const updated = updateKycRequest(id, { status: 'Rejected', decisionReason: reason });
  if (!updated) return res.status(404).json({ code: 'KYCREQ_NOT_FOUND', message: 'KYC request not found' });
  return res.status(204).send();
});

export default router;
