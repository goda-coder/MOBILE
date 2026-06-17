// lib/screens/enrollment_screen.dart
import 'package:flutter/material.dart';
import 'fingerprint_service.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nidCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  int _selectedFinger = 1; // السبابة اليمنى
  bool _deviceOpen = false;
  bool _loading = false;
  String _status = '';
  bool _statusOk = true;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  @override
  void dispose() {
    _nidCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String msg, {bool ok = true}) {
    setState(() {
      _status = msg;
      _statusOk = ok;
    });
  }

  Future<void> _checkDevice() async {
    try {
      final data = await FingerprintService.getDeviceStatus();
      setState(() => _deviceOpen = data['device_open'] == true);
    } catch (_) {
      _setStatus('تعذر الوصول إلى خدمة البصمة', ok: false);
    }
  }

  Future<void> _toggleDevice() async {
    setState(() => _loading = true);
    try {
      final data = _deviceOpen
          ? await FingerprintService.closeDevice()
          : await FingerprintService.openDevice();

      if (data['success'] == true) {
        setState(() => _deviceOpen = !_deviceOpen);
        _setStatus(data['message'] ?? (_deviceOpen ? 'تم الاتصال' : 'تم قطع الاتصال'));
      } else {
        _setStatus(data['error'] ?? 'خطأ غير معروف', ok: false);
      }
    } catch (e) {
      _setStatus('خطأ: $e', ok: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startEnrollment() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_deviceOpen) {
      _setStatus('الجهاز غير متصل. اضغط "تشغيل الجهاز" أولاً', ok: false);
      return;
    }

    setState(() => _loading = true);
    _setStatus('ضع الإصبع على الجهاز 3 مرات...');

    try {
      final data = await FingerprintService.enroll(
        nationalId: _nidCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        fingerIndex: _selectedFinger,
      );

      if (data['success'] == true) {
        _setStatus(
          '✅ تم التسجيل بنجاح\n'
          'جودة البصمة: ${data['quality']}/100\n'
          'حجم القالب: ${data['template_size']} بايت',
        );
        // مسح الفورم بعد النجاح
        _nidCtrl.clear();
        _nameCtrl.clear();
        _phoneCtrl.clear();
      } else {
        _setStatus('❌ ${data['error']}', ok: false);
      }
    } catch (e) {
      _setStatus('❌ خطأ: $e', ok: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل البصمة'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_deviceOpen ? Icons.usb : Icons.usb_off),
            tooltip: _deviceOpen ? 'قطع الاتصال' : 'توصيل الجهاز',
            onPressed: _loading ? null : _toggleDevice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Device status chip ──────────────────────────────────────
              Center(
                child: Chip(
                  avatar: Icon(
                    _deviceOpen ? Icons.fingerprint : Icons.fingerprint,
                    color: _deviceOpen ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                  label: Text(
                    _deviceOpen ? 'الجهاز متصل' : 'الجهاز غير متصل',
                    style: TextStyle(
                      color: _deviceOpen ? Colors.green.shade800 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor:
                      _deviceOpen ? Colors.green.shade50 : Colors.grey.shade100,
                ),
              ),

              if (!_deviceOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _toggleDevice,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('تشغيل الجهاز'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Form fields ─────────────────────────────────────────────
              TextFormField(
                controller: _nidCtrl,
                decoration: _inputDec('الرقم القومي', Icons.badge),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الرقم القومي مطلوب' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDec('الاسم كاملاً', Icons.person),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneCtrl,
                decoration: _inputDec('رقم الهاتف (اختياري)', Icons.phone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              // ── Finger selector ─────────────────────────────────────────
              DropdownButtonFormField<int>(
                value: _selectedFinger,
                decoration: _inputDec('الإصبع', Icons.touch_app),
                items: List.generate(fingerNames.length, (i) {
                  return DropdownMenuItem(value: i, child: Text(fingerNames[i]));
                }),
                onChanged: (v) => setState(() => _selectedFinger = v!),
              ),
              const SizedBox(height: 24),

              // ── Enroll button ───────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_loading || !_deviceOpen) ? null : _startEnrollment,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint, size: 24),
                  label: Text(_loading ? 'جاري التسجيل...' : 'بدء التسجيل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Status box ──────────────────────────────────────────────
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _statusOk
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _statusOk ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _statusOk
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
        ),
      );
}
