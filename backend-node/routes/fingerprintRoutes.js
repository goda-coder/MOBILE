// routes/fingerprintRoutes.js
import express from 'express';
import {
  deviceStatus,
  openDevice,
  closeDevice,
  enrollFingerprint,
  verifyFingerprint,
  getUser,
} from '../controllers/fingerprintController.js';

const router = express.Router();

// Device management
router.get("/device/status", deviceStatus);
router.post("/device/open", openDevice);
router.post("/device/close", closeDevice);

// Core operations
router.post("/enroll", enrollFingerprint);
router.post("/verify", verifyFingerprint);

// User info
router.get("/user/:national_id", getUser);

export default router;
