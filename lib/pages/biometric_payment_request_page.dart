import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/inline_alert.dart';

class BiometricPaymentRequestPage extends ConsumerStatefulWidget {
  const BiometricPaymentRequestPage({super.key});

  @override
  ConsumerState<BiometricPaymentRequestPage> createState() =>
      _BiometricPaymentRequestPageState();
}

class _BiometricPaymentRequestPageState
    extends ConsumerState<BiometricPaymentRequestPage> {
  final _phoneController = TextEditingController(text: '+20');
  final _amountController = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _transactionStatus;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final amountText = _amountController.text.trim();

    if (phone.isEmpty) {
      setState(() => _error = 'Enter the customer phone number');
      return;
    }
    if (amountText.isEmpty) {
      setState(() => _error = 'Enter the amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    final auth = ref.read(authControllerProvider).value;
    final merchantId = auth?.phoneNumber;
    if (merchantId == null || merchantId.isEmpty) {
      setState(() => _error = 'Merchant phone not found. Sign in again.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
      _transactionStatus = null;
    });

    final status = await ref
        .read(biometricPaymentServiceProvider.notifier)
        .initiatePayment(
          merchantId: merchantId,
          targetUserId: phone,
          amountEgp: amount,
        );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _transactionStatus = status;
    });

    if (status == "SUCCESS") {
      context.pushReplacement('/payment-success');
    } else if (status == "FAILED" || status == "TIMEOUT") {
      setState(() => _error = status == "TIMEOUT"
          ? 'Transaction timed out. The customer may not have responded.'
          : 'Transaction failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(biometricPaymentServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Biometric Payment'),
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Enter the customer details to request a biometric payment.',
              style: TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 24),
            AppInput(
              controller: _phoneController,
              label: 'Customer phone number',
              hint: '+201001234567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _amountController,
              label: 'Amount (EGP)',
              hint: 'e.g. 150.00',
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              InlineAlert(message: _error!, type: AlertType.danger),
              const SizedBox(height: 16),
            ],
            if (_transactionStatus == "PENDING") ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Waiting for merchant device…'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (!paymentState.isConnected) ...[
              const InlineAlert(
                message:
                    'Not connected to merchant system. Connect from the profile page first.',
                type: AlertType.warning,
              ),
              const SizedBox(height: 16),
            ],
            AppButton(
              label: _transactionStatus == "PENDING"
                  ? 'Processing…'
                  : 'Send Payment Request',
              icon: Icons.send,
              loading: _busy,
              onPressed:
                  (_busy || !paymentState.isConnected) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
