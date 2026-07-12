import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/widgets/inline_alert.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';
import '../models/transfer_data.dart';
import '../services/kyc_guard.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});
  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String? _error;
  final bool _busy = false;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (!await KycGuard.ensureVerified(context, ref)) return;

    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount (e.g. 25.00).');
      return;
    }

    final idempotencyRef =
        'tr-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
    final data = TransferData(
      recipient: _recipient.text.trim(),
      amountMinor: minor,
      amountFormatted: formatMoney(minor),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      idempotencyRef: idempotencyRef,
    );

    if (mounted) context.push('/fraud-detection', extra: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send money'),
        centerTitle: true,
        forceMaterialTransparency: true,
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const InlineAlert(
              message:
                  'Transfer to another wallet by phone, email, or wallet ID. '
                  'Transfers are atomic and idempotent.',
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorCard(message: _error!),
              const SizedBox(height: 12)
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  AppInput(
                    controller: _recipient,
                    label: 'Recipient',
                    hint: 'phone, email, or wallet ID',
                  ),
                  const SizedBox(height: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount',
                            style: TextStyle(
                                color: AppColors.ink300,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            suffixText: 'EGP',
                            suffixStyle: AppTheme.numTextStyle(
                                color: AppColors.ink400, fontSize: 13),
                          ),
                          style: AppTheme.numTextStyle(fontSize: 26),
                        ),
                      ]),
                  const SizedBox(height: 14),
                  AppInput(
                    controller: _desc,
                    label: 'Description (optional)',
                    hint: "What's this for?",
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                        label: 'Send',
                        icon: Icons.send,
                        onPressed: _submit,
                        loading: _busy,
                        expand: true),
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
