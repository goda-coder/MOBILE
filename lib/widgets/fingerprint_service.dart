// lib/widgets/fingerprint_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class FingerprintService {
  // استخدم الخلفية المحلية التي تعمل على 8081
  static const String _baseUrl = 'http://localhost:8081/api/fingerprint';
  

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ─── Device ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDeviceStatus() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/device/status'))
        .timeout(const Duration(seconds: 5));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> openDevice() async {
    final res = await http
        .post(Uri.parse('$_baseUrl/device/open'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> closeDevice() async {
    final res = await http
        .post(Uri.parse('$_baseUrl/device/close'), headers: _headers)
        .timeout(const Duration(seconds: 5));
    return jsonDecode(res.body);
  }

  // ─── Enrollment ────────────────────────────────────────────────────────────

  /// finger_index: 0=R.Thumb, 1=R.Index ... 6=L.Index (الافتراضي السبابة اليمين)
  static Future<Map<String, dynamic>> enroll({
    required String nationalId,
    required String fullName,
    String phone = '',
    int fingerIndex = 1,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/enroll'),
          headers: _headers,
          body: jsonEncode({
            'national_id': nationalId,
            'full_name': fullName,
            'phone': phone,
            'finger_index': fingerIndex,
          }),
        )
        .timeout(const Duration(seconds: 60)); // 60s للـ 3 captures
    return jsonDecode(res.body);
  }

  // ─── Verification ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verify({
    required String nationalId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/verify'),
          headers: _headers,
          body: jsonEncode({'national_id': nationalId}),
        )
        .timeout(const Duration(seconds: 30));
    return jsonDecode(res.body);
  }

  // ─── User Info ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUser(String nationalId) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/user/$nationalId'))
        .timeout(const Duration(seconds: 5));
    return jsonDecode(res.body);
  }
}

// ─── Finger Names Helper ────────────────────────────────────────────────────
const List<String> fingerNames = [
  'الإبهام الأيمن',
  'السبابة اليمنى',
  'الوسطى اليمنى',
  'البنصر الأيمن',
  'الخنصر الأيمن',
  'الإبهام الأيسر',
  'السبابة اليسرى',
  'الوسطى اليسرى',
  'البنصر الأيسر',
  'الخنصر الأيسر',
];
