import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

class FingerprintLoginPage extends ConsumerStatefulWidget {
  const FingerprintLoginPage({super.key});

  @override
  ConsumerState<FingerprintLoginPage> createState() => _FingerprintLoginPageState();
}

class _FingerprintLoginPageState extends ConsumerState<FingerprintLoginPage> {
  final _fingerprintId = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _fingerprintId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final fingerprintId = _fingerprintId.text.trim();
    if (fingerprintId.isEmpty) {
      setState(() => _error = 'Enter the fingerprint identifier from your ZK device service.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).signInWithFingerprint(fingerprintId);
      if (mounted) context.go('/');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not sign in with fingerprint.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            const Text('Use your ZK9500 fingerprint device to log in.',
                style: TextStyle(color: AppColors.ink400, fontSize: 14)),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorCard(message: _error!),
              const SizedBox(height: 12),
            ],
            AppInput(
              controller: _fingerprintId,
              label: 'Fingerprint ID',
              hint: 'e.g. 8f0c4a2b-...',
            ),
            const SizedBox(height: 16),
            const Text(
              'This app assumes a local ZK9500 service provides the fingerprint identifier after a successful scan.',
              style: TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Sign in with fingerprint',
                onPressed: _submit,
                loading: _busy,
                expand: true,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
