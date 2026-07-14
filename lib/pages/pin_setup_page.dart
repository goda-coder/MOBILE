import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';

class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});
  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscured = true;
  bool _created = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 6 digits.');
      return;
    }
    const weakPins = [
      '000000', '111111', '222222', '333333', '444444',
      '555555', '666666', '777777', '888888', '999999',
      '123456', '654321',
    ];
    if (weakPins.contains(pin)) {
      setState(() => _error = 'This PIN is too common. Please choose a different one.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      await ref.read(authApiProvider).createPin(pin);
      await ref.read(authControllerProvider.notifier).setPinCreated();
      if (mounted) {
        setState(() => _created = true);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create PIN. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_created) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Security PIN'),
          forceMaterialTransparency: true,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        color: AppColors.success, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('PIN created successfully',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Security PIN is now active. You will need it to sign in and confirm transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.ink400),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child:                     AppButton(
                      label: 'Continue',
                      onPressed: () => context.go('/'),
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Security PIN'),
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
            const Text('Set your Security PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'This PIN will be required to sign in and confirm transactions.',
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
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: TextStyle(
                          fontSize: 28,
                          letterSpacing: 8,
                          color: AppColors.ink500),
                      labelText: 'New PIN',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscured,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 8,
                        color: AppColors.ink100),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: TextStyle(
                          fontSize: 28,
                          letterSpacing: 8,
                          color: AppColors.ink500),
                      labelText: 'Confirm PIN',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _obscured = !_obscured),
                      icon: Icon(
                          _obscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.ink400),
                      label: Text(
                          _obscured ? 'Show PIN' : 'Hide PIN',
                          style:
                              const TextStyle(color: AppColors.ink400, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Create PIN',
                      icon: Icons.check_circle_outline,
                      onPressed: _create,
                      loading: _busy,
                      expand: true,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
