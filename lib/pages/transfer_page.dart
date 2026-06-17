import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});
  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _recipient = TextEditingController();
  final _amount    = TextEditingController();
  final _desc      = TextEditingController();
  String? _error;
  String? _success;
  bool _busy = false;

  @override
  void dispose() {
    _recipient.dispose(); _amount.dispose(); _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _success = null; });
    
    // Check if KYC is verified first
    final isKycVerified = await ref.read(isKycVerifiedProvider.future).catchError((_) => false);
    if (!isKycVerified) {
      setState(() => _error = 'Complete identity verification first to proceed with transfer.');
      // Show a dialog and redirect to KYC
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('KYC Verification Required'),
            content: const Text('You must complete your identity verification before you can perform this operation.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) context.push('/kyc/status');
                },
                child: const Text('Go to KYC'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    final minor = parseMinor(_amount.text);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter a valid amount (e.g. 25.00).');
      return;
    }
    setState(() => _busy = true);
    try {
      // Idempotency key — server uses this as Transaction.Reference unique-key.
      final idempotencyRef = 'tr-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
      final r = await _doTransfer(idempotencyRef);
      setState(() {
        _success = 'Sent. New balance: ${formatMoney(r.newBalanceMinor)}';
        _recipient.clear(); _amount.clear(); _desc.clear();
      });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not complete transfer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future _doTransfer(String reference) {
    final minor = parseMinor(_amount.text)!;
    return ref.read(walletApiProvider).transfer(
      recipientIdentifier: _recipient.text.trim(),
      amountMinor: minor,
      reference: reference,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Transfer to another wallet by phone, email, or wallet ID. '
              'Transfers are atomic and idempotent.',
              style: TextStyle(color: AppColors.ink400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorCard(message: _error!), const SizedBox(height: 12)],
            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Transfer sent.',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_success!, style: const TextStyle(color: AppColors.ink200)),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => context.go('/'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    child: const Text('Back to wallet ↗'),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  AppInput(
                    controller: _recipient, label: 'Recipient',
                    hint: 'phone, email, or wallet ID',
                  ),
                  const SizedBox(height: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Amount',
                        style: TextStyle(color: AppColors.ink300, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: 'EGP',
                        suffixStyle: AppTheme.numTextStyle(color: AppColors.ink400, fontSize: 13),
                      ),
                      style: AppTheme.numTextStyle(fontSize: 26),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  AppInput(
                    controller: _desc, label: 'Description (optional)',
                    hint: "What's this for?",
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(label: 'Send', icon: Icons.send,
                        onPressed: _submit, loading: _busy, expand: true),
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
