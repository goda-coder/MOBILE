// lib/screens/verification_screen.dart
import 'package:flutter/material.dart';
import 'fingerprint_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  final _nidCtrl = TextEditingController();
  bool _loading = false;
  _VerifyResult? _result;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nidCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final nid = _nidCtrl.text.trim();
    if (nid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل الرقم القومي أولاً')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final data = await FingerprintService.verify(nationalId: nid);
      setState(() {
        _result = _VerifyResult(
          matched: data['matched'] == true,
          score: data['score'] ?? 0,
          message: data['message'] ?? '',
          nationalId: nid,
        );
      });
    } catch (e) {
      setState(() {
        _result = _VerifyResult(
          matched: false,
          score: 0,
          message: 'خطأ في الاتصال: $e',
          nationalId: nid,
        );
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الهوية'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── NID Field ─────────────────────────────────────────────────
            TextField(
              controller: _nidCtrl,
              decoration: InputDecoration(
                labelText: 'الرقم القومي',
                prefixIcon: const Icon(Icons.badge, color: Color(0xFF1A237E)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF1A237E), width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 28),

            // ── Fingerprint animation ─────────────────────────────────────
            Center(
              child: ScaleTransition(
                scale: _loading ? _pulse : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _loading
                        ? const Color(0xFF1A237E).withOpacity(0.12)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: _loading
                          ? const Color(0xFF1A237E)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: _loading
                        ? const Color(0xFF1A237E)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'ضع إصبعك على الجهاز...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A237E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // ── Verify button ─────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _verify,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user, size: 22),
                label:
                    Text(_loading ? 'جاري التحقق...' : 'تحقق من البصمة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Result card ───────────────────────────────────────────────
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

// ─── Result Card ─────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final _VerifyResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.matched ? Colors.green : Colors.red;
    final icon = result.matched ? Icons.check_circle : Icons.cancel;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 52),
          const SizedBox(height: 10),
          Text(
            result.matched ? 'تم التعرف على الهوية' : 'البصمة غير متطابقة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
          if (result.matched) ...[
            const SizedBox(height: 8),
            Text(
              'درجة التطابق: ${result.score}/100',
              style: TextStyle(color: color.shade600, fontSize: 14),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────
class _VerifyResult {
  final bool matched;
  final int score;
  final String message;
  final String nationalId;

  const _VerifyResult({
    required this.matched,
    required this.score,
    required this.message,
    required this.nationalId,
  });
}
