import express from 'express';
import multer from 'multer';
import { createKycRequest, getKycStatus } from '../store.js';

const router = express.Router();
const upload = multer();

router.get('/status', (req, res) => {
  const status = getKycStatus(req.user.userId);
  return res.json(status);
});

router.post('/submit', upload.fields([
  { name: 'idFront' },
  { name: 'idBack' },
  { name: 'selfie' },
]), (req, res) => {
  const { documentType } = req.body;
  if (!documentType || !req.files || !req.files.idFront || !req.files.selfie) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Missing documentType, idFront, or selfie' });
  }
  const kycRequest = createKycRequest({
    userId: req.user.userId,
    documentType,
    status: 'Pending',
    matchPercentage: 0.0,
    warnings: [],
  });
  return res.status(201).json({
    kycRequestId: kycRequest.id,
    status: kycRequest.status,
    matchPercentage: kycRequest.matchPercentage,
    spoofScore: 0.0,
    ocrConfidence: 0.0,
    warnings: [],
  });
});

router.post('/liveness/challenge', (req, res) => {
  return res.json({
    challengeId: `challenge_${Date.now()}`,
    action: 'blink',
    ttlSeconds: 90,
  });
});

router.post('/liveness/verify', (req, res) => {
  const { challengeId, action, frames } = req.body;
  if (!challengeId || !action || !frames) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'Missing liveness challenge fields' });
  }
  return res.json({ passed: true, confidence: 0.97, reason: null });
});

export default router;
