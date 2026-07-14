import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';

class PinLoginPage extends ConsumerStatefulWidget {
  const PinLoginPage({super.key});
  @override
  ConsumerState<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends ConsumerState<PinLoginPage> {
  final _pinController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscured = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter your 6-digit PIN.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      await ref.read(authApiProvider).verifyPin(pin);
      if (mounted) {
        // Router redirect will send to / or /account-setup based on KYC status
        context.go('/');
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not verify PIN.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter PIN'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.brandPrimary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Enter your Security PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Your PIN is required to access your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink400, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  if (_error != null) ...[
                    InlineAlert(message: _error!, type: AlertType.danger),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _pinController,
                    obscureText: _obscured,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 8,
                        color: AppColors.ink100),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 8,
                          color: AppColors.ink500),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.ink400),
                        onPressed: () =>
                            setState(() => _obscured = !_obscured),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Unlock',
                      icon: Icons.lock_open_outlined,
                      onPressed: _verify,
                      loading: _busy,
                      expand: true,
                    ),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out',
                  style: TextStyle(color: AppColors.ink400)),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
