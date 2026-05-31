import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/liveness_capture.dart';
import '../widgets/status_pill.dart';

enum _Phase { intro, capture, result }

class KycLivenessPage extends ConsumerStatefulWidget {
  const KycLivenessPage({super.key});
  @override
  ConsumerState<KycLivenessPage> createState() => _KycLivenessPageState();
}

class _KycLivenessPageState extends ConsumerState<KycLivenessPage> {
  _Phase _phase = _Phase.intro;
  LivenessChallenge? _challenge;
  LivenessVerifyResponse? _result;
  String? _error;
  bool _busy = false;

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    try {
      final c = await ref.read(kycApiProvider).issueChallenge();
      setState(() { _challenge = c; _phase = _Phase.capture; });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not issue challenge.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFrames(List<String> frames) async {
    final c = _challenge;
    if (c == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final r = await ref.read(kycApiProvider).verifyLiveness(
        challengeId: c.challengeId, action: c.action, base64Frames: frames,
      );
      setState(() { _result = r; _phase = _Phase.result; });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Verification failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liveness check')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              "A quick movement-based check that proves you're really here.",
              style: TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorCard(message: _error!), const SizedBox(height: 12)],

            if (_phase == _Phase.intro)
              Card(child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    "You'll be asked to perform a small action — blink, nod, or turn your head. "
                    "We capture about 4 seconds of video and run it through our liveness model.",
                    style: TextStyle(color: AppColors.ink300, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  for (final tip in const [
                    'Make sure your face is well lit.',
                    'Take your glasses off if possible.',
                    "Be in a quiet, distraction-free spot.",
                  ]) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  ', style: TextStyle(color: AppColors.ink400)),
                      Expanded(child: Text(tip,
                          style: const TextStyle(color: AppColors.ink400, fontSize: 13))),
                    ]),
                    const SizedBox(height: 2),
                  ],
                  const SizedBox(height: 12),
                  AppButton(label: 'Start liveness check',
                      onPressed: _start, loading: _busy),
                ]),
              ))
            else if (_phase == _Phase.capture)
              Card(child: Padding(
                padding: const EdgeInsets.all(18),
                child: LivenessCapture(
                  action: _challenge!.action,
                  onFrames: _onFrames,
                ),
              ))
            else if (_phase == _Phase.result && _result != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: (_result!.passed ? AppColors.success : AppColors.danger)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_result!.passed ? Icons.check : Icons.close,
                        size: 32,
                        color: _result!.passed ? AppColors.success : AppColors.danger),
                  ),
                  const SizedBox(height: 14),
                  Text(_result!.passed ? 'Liveness confirmed.' : 'Could not confirm liveness.',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    'Confidence ${(_result!.confidence * 100).round()}%'
                    + (_result!.reason != null ? ' · ${_result!.reason}' : ''),
                    style: const TextStyle(color: AppColors.ink400),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Try another check',
                    onPressed: () => setState(() {
                      _phase = _Phase.intro;
                      _challenge = null; _result = null;
                    }),
                  ),
                ]),
              )),
          ]),
        ),
      ),
    );
  }
}
