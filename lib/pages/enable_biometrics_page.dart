import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

class EnableBiometricsPage extends ConsumerStatefulWidget {
  const EnableBiometricsPage({
    super.key,
    this.phone,
    this.password,
  });

  final String? phone;
  final String? password;

  @override
  ConsumerState<EnableBiometricsPage> createState() =>
      _EnableBiometricsPageState();
}

class _EnableBiometricsPageState extends ConsumerState<EnableBiometricsPage> {
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingBiometricCredentialsProvider.notifier).set(null);
    });
  }

  Future<void> _enable() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    final result =
        await ref.read(biometricControllerProvider.notifier).enableBiometrics(
              phone: widget.phone ?? '',
              password: widget.password ?? '',
            );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result == null) {
      context.go('/');
    } else {
      setState(() => _error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(biometricControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.brandGradient.createShader(b),
                  child: const Text(
                    'wallet.',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 48),
              const Icon(Icons.fingerprint,
                  size: 48, color: AppColors.brandPrimary),
              const SizedBox(height: 24),
              const Text('Secure Access',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Enable biometric login to access your account instantly '
                'and securely without entering your credentials every time.',
                style: TextStyle(color: AppColors.ink400, fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 16),
              ],
              if (state.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!state.isDeviceSupported)
                const ErrorCard(
                  title: 'Not Supported',
                  message:
                      'This device does not support biometric authentication.',
                )
              else if (!state.hasBiometricsEnrolled)
                const ErrorCard(
                  title: 'No Biometrics Enrolled',
                  message: 'Please add a fingerprint or face ID in your device '
                      'settings first.',
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Enable Biometric Login',
                  onPressed: !state.isLoading &&
                          state.isDeviceSupported &&
                          state.hasBiometricsEnrolled
                      ? _enable
                      : null,
                  loading: _busy,
                  expand: true,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
