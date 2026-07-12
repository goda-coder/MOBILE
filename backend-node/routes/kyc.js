import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { createKycRequest, getKycStatus } from '../store.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadDir = path.join(__dirname, '..', 'uploads', 'kyc');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    const name = `${req.user.userId}_${Date.now()}_${file.fieldname}${ext}`;
    cb(null, name);
  },
});

const upload = multer({ storage });

const router = express.Router();

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

  const idFrontFile = req.files.idFront[0];
  const idBackFile = req.files.idBack?.[0] ?? null;
  const selfieFile = req.files.selfie[0];

  const kycRequest = createKycRequest({
    userId: req.user.userId,
    fullName: req.user.fullName,
    phoneNumber: req.user.phoneNumber,
    documentType,
    status: 'Pending',
    matchPercentage: 0.0,
    warnings: [],
    idFrontPath: idFrontFile.filename,
    idBackPath: idBackFile?.filename ?? null,
    selfiePath: selfieFile.filename,
  });

  return res.status(201).json({
    kycRequestId: kycRequest.id,
    status: kycRequest.status,
    matchPercentage: kycRequest.matchPercentage,
    spoofScore: 0.0,
    ocrConfidence: 0.0,
    warnings: [],
    idFrontUrl: `/uploads/kyc/${idFrontFile.filename}`,
    idBackUrl: idBackFile ? `/uploads/kyc/${idBackFile.filename}` : null,
    selfieUrl: `/uploads/kyc/${selfieFile.filename}`,
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
