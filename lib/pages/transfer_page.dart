import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/widgets/inline_alert.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';
import '../models/transfer_data.dart';
import '../services/auth_guards.dart';
import '../state/providers.dart';
import '../utils/self_transfer.dart';

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
  bool _busy = false;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (!await AuthGuards.requireWalletAccess(context, ref)) return;

    final recipient = _recipient.text.trim();
    if (recipient.isEmpty) {
      setState(() => _error = 'Please enter a recipient.');
      return;
    }

    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount (e.g. 25.00).');
      return;
    }

    final auth = ref.read(authControllerProvider).value;
    if (isSelfTransfer(recipient,
        userId: auth?.userId, phoneNumber: auth?.phoneNumber)) {
      setState(() => _error = 'You cannot transfer to your own account.');
      return;
    }

    setState(() => _busy = true);
    try {
      // 1 & 2. Verify Recipient and KYC status
      try {
        await ref.read(walletApiProvider).validateRecipient(recipient);
      } on ApiError catch (e) {
        if (e.code == 'RECIPIENT_NOT_FOUND') {
          setState(() => _error = 'Recipient account not found.');
        } else if (e.code == 'RECIPIENT_KYC_NOT_VERIFIED') {
          setState(() => _error = 'Recipient KYC not verified.');
        } else {
          setState(() => _error = e.message);
        }
        return;
      }

      // 3. Verify Sender Balance
      final summary = await ref.read(walletApiProvider).summary();
      if (summary.balanceMinor < minor) {
        setState(() => _error = 'Insufficient balance.');
        return;
      }

      // 4. Verify Transfer Limits
      final limits = await ref.read(walletApiProvider).transferLimits();
      if (limits.dailyRemaining == 0) {
        _showLimitDialog(
          title: 'Daily Limit Reached',
          message:
              'You have reached your daily transfer limit. Your daily limit will reset on ${_formatReset(limits.dailyResetAt)}.',
        );
        return;
      }
      if (limits.monthlyRemaining == 0) {
        _showLimitDialog(
          title: 'Monthly Limit Reached',
          message:
              'You have reached your monthly transfer limit. Your monthly limit will reset on ${_formatReset(limits.monthlyResetAt)}.',
        );
        return;
      }
      if (minor > limits.dailyRemaining) {
        _showLimitDialog(
          title: 'Daily Limit',
          message:
              'The entered amount exceeds your remaining daily transfer limit. You can only send up to ${formatAmount(limits.dailyRemaining)} today.',
        );
        return;
      }
      if (minor > limits.monthlyRemaining) {
        _showLimitDialog(
          title: 'Monthly Limit',
          message:
              'The entered amount exceeds your remaining monthly transfer limit. You can only send up to ${formatAmount(limits.monthlyRemaining)} this month.',
        );
        return;
      }

      final idempotencyRef =
          'tr-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
      final data = TransferData(
        recipient: recipient,
        amountMinor: minor,
        amountFormatted: formatMoney(minor),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        idempotencyRef: idempotencyRef,
      );

      if (mounted) context.push('/transfer-confirmation', extra: data);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not process validation: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showLimitDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Flexible(child: Text(title)),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatReset(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inHours < 24) {
      return 'Tomorrow at 12:00 AM';
    }
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
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
