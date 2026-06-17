// controllers/fingerprintController.js
// Node.js بيتكلم مع Python ZK Service

import axios from 'axios';

const ZK_SERVICE_URL = process.env.ZK_SERVICE_URL || 'http://localhost:5005';

// ─── Helper ───────────────────────────────────────────────────────────────────
async function zkPost(endpoint, body = {}) {
  const res = await axios.post(`${ZK_SERVICE_URL}${endpoint}`, body, {
    timeout: 30000, // 30s للـ enrollment عشان 3 captures
  });
  return res.data;
}

async function zkGet(endpoint) {
  const res = await axios.get(`${ZK_SERVICE_URL}${endpoint}`, {
    timeout: 5000,
  });
  return res.data;
}

// ─── Controllers ──────────────────────────────────────────────────────────────

/**
 * GET /api/fingerprint/device/status
 * Check if ZK device is connected
 */
const deviceStatus = async (req, res) => {
  try {
    const data = await zkGet("/health");
    res.json({ success: true, device_open: data.device_open });
  } catch (err) {
    res.status(503).json({
      success: false,
      error: "Python ZK Service غير متاح. تأكد أنه شغال.",
    });
  }
};

/**
 * POST /api/fingerprint/device/open
 * Connect to the ZK9500 reader
 */
const openDevice = async (req, res) => {
  try {
    const data = await zkPost("/device/open");
    res.json(data);
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.response?.data?.error || err.message,
    });
  }
};

/**
 * POST /api/fingerprint/device/close
 */
const closeDevice = async (req, res) => {
  try {
    const data = await zkPost("/device/close");
    res.json(data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

/**
 * POST /api/fingerprint/enroll
 * Body: { national_id, full_name, phone, finger_index }
 * بيشغل الـ 3-capture enrollment
 */
const enrollFingerprint = async (req, res) => {
  const { national_id, full_name, phone, finger_index = 1 } = req.body;

  if (!national_id || !full_name) {
    return res.status(400).json({
      success: false,
      error: "national_id و full_name مطلوبان",
    });
  }

  try {
    const data = await zkPost("/enroll", {
      national_id,
      full_name,
      phone: phone || "",
      finger_index: Number(finger_index),
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.response?.data?.error || err.message,
    });
  }
};

/**
 * POST /api/fingerprint/verify
 * Body: { national_id }
 * يلتقط بصمة ويطابقها
 */
const verifyFingerprint = async (req, res) => {
  const { national_id } = req.body;

  if (!national_id) {
    return res.status(400).json({
      success: false,
      error: "national_id مطلوب",
    });
  }

  try {
    const data = await zkPost("/verify", { national_id });

    // لو استخدمت JWT أو session، ممكن تضيف token هنا
    res.json({
      ...data,
      message: data.matched
        ? "✅ تم التحقق من الهوية بنجاح"
        : "❌ البصمة غير متطابقة",
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.response?.data?.error || err.message,
    });
  }
};

/**
 * GET /api/fingerprint/user/:national_id
 * جلب بيانات المستخدم والأصابع المسجلة
 */
const getUser = async (req, res) => {
  try {
    const data = await zkGet(`/users/${req.params.national_id}`);
    res.json(data);
  } catch (err) {
    const status = err.response?.status || 500;
    res.status(status).json({
      success: false,
      error: err.response?.data?.error || err.message,
    });
  }
};

export {
  deviceStatus,
  openDevice,
  closeDevice,
  enrollFingerprint,
  verifyFingerprint,
  getUser,
};
