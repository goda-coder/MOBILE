import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+201');
  final _pw = TextEditingController();
  String _role = 'Customer';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    // Store pending credentials so the router redirect picks them up
    ref.read(pendingBiometricCredentialsProvider.notifier).set(
      {'phone': _phone.text.trim(), 'password': _pw.text},
    );
    try {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            password: _pw.text,
            role: _role,
          );
      if (mounted) context.go('/enable-biometrics');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create account.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'A few details. You can verify your identity afterwards.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 12)
              ],
              AppInput(
                  controller: _name,
                  label: 'Full name',
                  hint: 'Ahmed Hassan',
                  autofillHints: const [AutofillHints.name]),
              const SizedBox(height: 14),
              AppInput(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email]),
              const SizedBox(height: 14),
              AppInput(
                  controller: _phone,
                  label: 'Phone',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber]),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Choose role",
                      style: TextStyle(
                        color: AppColors.ink300,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 6),
                  InputDecorator(
                    decoration: const InputDecoration(
                        constraints:
                            BoxConstraints(maxHeight: 52.0, minHeight: 52.0)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _role,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'Customer', child: Text('Customer')),
                          DropdownMenuItem(
                              value: 'Merchant', child: Text('Merchant')),
                          DropdownMenuItem(
                              value: 'Admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _role = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppInput(
                  controller: _pw,
                  label: 'Password',
                  obscure: true,
                  helper:
                      'At least 10 characters, including a number and a symbol.',
                  autofillHints: const [AutofillHints.newPassword]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                    label: 'Create account',
                    onPressed: _submit,
                    loading: _busy,
                    expand: true),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('API: $apiBaseUrl',
                    style:
                        const TextStyle(color: AppColors.ink400, fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Center(
                  child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Sign in'),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
