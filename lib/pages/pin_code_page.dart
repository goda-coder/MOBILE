import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models/transfer_data.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';

class PinCodePage extends ConsumerStatefulWidget {
  const PinCodePage({super.key, required this.data});
  final TransferData data;

  @override
  ConsumerState<PinCodePage> createState() => _PinCodePageState();
}

class _PinCodePageState extends ConsumerState<PinCodePage> {
  final _pinController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscured = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_pinController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your PIN');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(walletApiProvider).transfer(
            recipientIdentifier: widget.data.recipient,
            amountMinor: widget.data.amountMinor,
            reference: widget.data.idempotencyRef,
            description: widget.data.description,
          );
      if (mounted) context.go('/');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not complete transfer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm PIN'),
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
            const Text('Enter your PIN to confirm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                      label: 'Confirm',
                      icon: Icons.check_circle_outline,
                      onPressed: _confirm,
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
