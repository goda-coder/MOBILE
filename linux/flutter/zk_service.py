"""
InstaShield — ZK9500 Python Service (Windows)
بيشتغل كـ HTTP server على port 5005
Node.js بيتكلم معاه عبر HTTP
"""

from flask import Flask, jsonify, request
from pyzkfp import ZKFP2
import sqlite3
import hashlib
import threading
import base64
import os
from pathlib import Path

app = Flask(__name__)
DB_PATH = Path(__file__).parent / "instashield.db"

# ─── Global reader instance ───────────────────────────────────────────────────
reader_lock = threading.Lock()
zkfp = None
device_open = False

# ─── DB Setup ─────────────────────────────────────────────────────────────────
SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    national_id TEXT UNIQUE NOT NULL,
    full_name   TEXT NOT NULL,
    phone       TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS fingerprints (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        INTEGER NOT NULL,
    finger_index   INTEGER NOT NULL,
    template       BLOB NOT NULL,
    template_sha256 TEXT NOT NULL,
    quality        INTEGER,
    enrolled_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE (user_id, finger_index)
);
CREATE INDEX IF NOT EXISTS idx_fp_sha ON fingerprints(template_sha256);
"""

def get_db():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    return con

def init_db():
    with get_db() as con:
        con.executescript(SCHEMA)

# ─── Reader Helpers ───────────────────────────────────────────────────────────
def open_reader():
    global zkfp, device_open
    zkfp = ZKFP2()
    zkfp.Init()
    count = zkfp.GetDeviceCount()
    if count == 0:
        zkfp.Terminate()
        raise RuntimeError("لا يوجد جهاز ZKTeco متصل. تحقق من USB.")
    zkfp.OpenDevice(0)
    zkfp.DBInit()
    device_open = True

def close_reader():
    global zkfp, device_open
    if device_open and zkfp:
        try:
            zkfp.DBFree()
            zkfp.CloseDevice()
        finally:
            zkfp.Terminate()
        device_open = False
        zkfp = None

def capture_once(timeout_ms=15000):
    import time
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        result = zkfp.AcquireFingerprint()
        if result:
            template, image = result
            return template, image
        time.sleep(0.05)
    raise TimeoutError("لم يتم اكتشاف أي بصمة خلال المهلة المحددة.")

def do_enroll():
    """3-capture enrollment — returns (merged_template_bytes, quality)"""
    templates = []
    quality = 0
    for i in range(3):
        template, _ = capture_once()
        templates.append(template)
        try:
            q = int(zkfp.GetParameters(2))
            quality = max(quality, q)
        except Exception:
            pass
    merged = zkfp.DBMerge(*templates)
    return merged, quality

def do_verify(stored_template_b64: str):
    """One capture then match against stored template. Returns score 0-100."""
    stored = base64.b64decode(stored_template_b64)
    zkfp.DBAdd(1, stored)          # register template with id=1 temporarily
    live_template, _ = capture_once()
    score = zkfp.DBIdentify(live_template)   # returns (id, score) or None
    zkfp.DBFree()
    zkfp.DBInit()
    if score is None:
        return 0
    # DBIdentify returns (fid, score) tuple
    return score[1] if isinstance(score, tuple) else int(score)

# ─── API Routes ───────────────────────────────────────────────────────────────

@app.route("/health")
def health():
    return jsonify({"status": "ok", "device_open": device_open})

@app.route("/device/open", methods=["POST"])
def api_open():
    with reader_lock:
        try:
            if device_open:
                return jsonify({"success": True, "message": "الجهاز متصل بالفعل"})
            open_reader()
            return jsonify({"success": True, "message": "تم الاتصال بالجهاز بنجاح"})
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

@app.route("/device/close", methods=["POST"])
def api_close():
    with reader_lock:
        close_reader()
        return jsonify({"success": True})

@app.route("/enroll", methods=["POST"])
def api_enroll():
    """
    Body: { national_id, full_name, phone, finger_index }
    يسجل بصمة جديدة (3 captures) ويحفظها في DB
    """
    data = request.json or {}
    national_id  = data.get("national_id", "").strip()
    full_name    = data.get("full_name", "").strip()
    phone        = data.get("phone", "").strip()
    finger_index = int(data.get("finger_index", 1))

    if not national_id or not full_name:
        return jsonify({"success": False, "error": "national_id و full_name مطلوبان"}), 400

    with reader_lock:
        if not device_open:
            return jsonify({"success": False, "error": "الجهاز غير متصل، اتصل بـ /device/open أولاً"}), 400
        try:
            template, quality = do_enroll()
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    sha = hashlib.sha256(template).hexdigest()
    template_b64 = base64.b64encode(template).decode()

    with get_db() as con:
        cur = con.execute(
            "INSERT INTO users(national_id, full_name, phone) VALUES (?,?,?) "
            "ON CONFLICT(national_id) DO UPDATE SET "
            "full_name=excluded.full_name, phone=excluded.phone RETURNING id",
            (national_id, full_name, phone),
        )
        user_id = cur.fetchone()[0]
        con.execute(
            "INSERT INTO fingerprints(user_id, finger_index, template, template_sha256, quality) "
            "VALUES (?,?,?,?,?) "
            "ON CONFLICT(user_id, finger_index) DO UPDATE SET "
            "template=excluded.template, template_sha256=excluded.template_sha256, "
            "quality=excluded.quality, enrolled_at=CURRENT_TIMESTAMP",
            (user_id, finger_index, template, sha, quality),
        )

    return jsonify({
        "success": True,
        "user_id": user_id,
        "quality": quality,
        "template_size": len(template),
        "sha256_prefix": sha[:16],
    })

@app.route("/verify", methods=["POST"])
def api_verify():
    """
    Body: { national_id }
    يلتقط بصمة حية ويطابقها مع المخزنة
    """
    data = request.json or {}
    national_id = data.get("national_id", "").strip()

    if not national_id:
        return jsonify({"success": False, "error": "national_id مطلوب"}), 400

    # جلب كل بصمات المستخدم
    with get_db() as con:
        rows = con.execute(
            "SELECT f.template, f.finger_index FROM fingerprints f "
            "JOIN users u ON u.id = f.user_id WHERE u.national_id = ?",
            (national_id,)
        ).fetchall()

    if not rows:
        return jsonify({"success": False, "error": "المستخدم غير مسجل"}), 404

    with reader_lock:
        if not device_open:
            return jsonify({"success": False, "error": "الجهاز غير متصل"}), 400
        try:
            live_template, _ = capture_once()
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

        # طابق مع كل البصمات المخزنة
        best_score = 0
        best_finger = -1
        for row in rows:
            stored = bytes(row["template"])
            zkfp.DBAdd(1, stored)
            result = zkfp.DBIdentify(live_template)
            zkfp.DBFree()
            zkfp.DBInit()
            if result:
                score = result[1] if isinstance(result, tuple) else int(result)
                if score > best_score:
                    best_score = score
                    best_finger = row["finger_index"]

    THRESHOLD = 50  # ZKTeco recommended minimum
    matched = best_score >= THRESHOLD

    return jsonify({
        "success": True,
        "matched": matched,
        "score": best_score,
        "finger_index": best_finger,
        "national_id": national_id,
    })

@app.route("/users/<national_id>", methods=["GET"])
def api_get_user(national_id):
    with get_db() as con:
        user = con.execute(
            "SELECT u.*, GROUP_CONCAT(f.finger_index) as fingers "
            "FROM users u LEFT JOIN fingerprints f ON u.id = f.user_id "
            "WHERE u.national_id = ? GROUP BY u.id",
            (national_id,)
        ).fetchone()
    if not user:
        return jsonify({"success": False, "error": "المستخدم غير موجود"}), 404
    return jsonify({
        "success": True,
        "user": {
            "id": user["id"],
            "national_id": user["national_id"],
            "full_name": user["full_name"],
            "phone": user["phone"],
            "enrolled_fingers": [int(x) for x in (user["fingers"] or "").split(",") if x],
        }
    })

# ─── Entry Point ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    init_db()
    print("=" * 50)
    print("  InstaShield ZK Service — port 5005")
    print("  افتح المتصفح: http://localhost:5005/health")
    print("=" * 50)
    app.run(host="0.0.0.0", port=5005, debug=False, threaded=True)
