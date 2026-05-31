import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _adminEmail = 'admin@wallet.local';
  static const _merchantEmail = 'merchant@wallet.local';
  static const _seedPassword = 'Admin1234!';

  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _quickLogin(String email, String password) async {
    if (_busy) return;
    _email.text = email;
    _password.text = password;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _busy = true; });
    try {
      await ref.read(authControllerProvider.notifier)
          .signIn(_email.text.trim(), _password.text);
      if (mounted) context.go('/');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not sign in.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Brand mark
              Row(children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                  child: const Text(
                    'wallet.',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
              const Text('WELCOME BACK',
                  style: TextStyle(color: AppColors.ink400, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 6),
              const Text('Sign in to your wallet.',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),

              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 12),
              ],

              AppInput(
                controller: _email, label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                hint: 'you@example.com',
              ),
              const SizedBox(height: 14),
              AppInput(
                controller: _password, label: 'Password',
                obscure: true,
                autofillHints: const [AutofillHints.password],
                hint: '••••••••',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppButton(label: 'Sign in', onPressed: _submit, loading: _busy, expand: true),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Login with fingerprint',
                  variant: AppButtonVariant.ghost,
                  onPressed: _busy ? null : () => context.go('/fingerprint-login'),
                  expand: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Admin login',
                    variant: AppButtonVariant.ghost,
                    onPressed: _busy ? null : () => _quickLogin(_adminEmail, _seedPassword),
                    expand: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Merchant login',
                    variant: AppButtonVariant.ghost,
                    onPressed: _busy ? null : () => _quickLogin(_merchantEmail, _seedPassword),
                    expand: true,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Don\'t have an account? Create one'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('API: $apiBaseUrl',
                    style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
              ),
              const SizedBox(height: 60),
              const Center(
                child: Text('Egyptian Wallet · Built in Dakahlia',
                    style: TextStyle(color: AppColors.ink400, fontSize: 11, letterSpacing: 2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
