import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/status_pill.dart';

enum _Method { card, wallet, fingerprint }

class TopUpPage extends ConsumerStatefulWidget {
  const TopUpPage({super.key, this.method});
  final String? method;

  @override
  ConsumerState<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends ConsumerState<TopUpPage> {
  _Method _method = _Method.card;
  final _amount = TextEditingController();
  final _first = TextEditingController();
  final _last  = TextEditingController();
  final _phone = TextEditingController(text: '+201');
  final _walletPhone = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final method = widget.method?.toLowerCase();
    if (method == 'wallet') {
      _method = _Method.wallet;
    } else if (method == 'fingerprint') {
      _method = _Method.fingerprint;
    }
  }

  @override
  void dispose() {
    _amount.dispose(); _first.dispose(); _last.dispose();
    _phone.dispose(); _walletPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    
    // Check if KYC is verified first
    final isKycVerified = await ref.read(isKycVerifiedProvider.future).catchError((_) => false);
    if (!isKycVerified) {
      setState(() => _error = 'Complete identity verification first to proceed with top-up.');
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
      setState(() => _error = 'Enter a valid amount.'); return;
    }
    if (minor > 1000000) {
      setState(() => _error = 'Max top-up is 10,000 EGP per transaction.'); return;
    }
    setState(() => _busy = true);
    try {
      final phoneNumber = ref.read(authControllerProvider).value?.phoneNumber ?? '';
      final r = await ref.read(paymentsApiProvider).checkout(
        amountMinor: minor,
        method: _method == _Method.card ? 'card' : _method == _Method.wallet ? 'wallet' : 'fingerprint',
        firstName: _first.text.trim(),
        lastName:  _last.text.trim(),
        email: '$phoneNumber@wallet.local',
        phoneNumber: _phone.text.trim(),
        walletPhoneNumber: _method == _Method.wallet ? _walletPhone.text.trim() : null,
      );
      if (_method == _Method.fingerprint) {
        if (mounted) {
          context.go('/fingerprint-auth?paymentIntentId=${Uri.encodeQueryComponent(r.paymentIntentId)}');
        }
        return;
      }
      final url = r.iframeUrl ?? r.walletRedirectUrl;
      if (url == null) {
        setState(() => _error = 'Gateway did not return a checkout URL.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not start checkout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              "Add funds via Paymob. We never see your card details — the iframe is hosted by Paymob.",
              style: TextStyle(color: AppColors.ink400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorCard(message: _error!), const SizedBox(height: 12)],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Method picker
                  const Text('Payment method',
                      style: TextStyle(color: AppColors.ink300, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _MethodTile(
                      active: _method == _Method.card,
                      onTap: () => setState(() => _method = _Method.card),
                      title: 'Card', sub: 'Visa · Mastercard · Meeza',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _MethodTile(
                      active: _method == _Method.wallet,
                      onTap: () => setState(() => _method = _Method.wallet),
                      title: 'Mobile wallet', sub: 'Vodafone · Etisalat · Orange',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _MethodTile(
                      active: _method == _Method.fingerprint,
                      onTap: () => setState(() => _method = _Method.fingerprint),
                      title: 'Fingerprint', sub: 'ZK9500 live 10 EGP',
                    )),
                  ]),
                  const SizedBox(height: 16),

                  const Text('Amount',
                      style: TextStyle(color: AppColors.ink300, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: numTextStyle(fontSize: 26),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: 'EGP',
                      suffixStyle: numTextStyle(color: AppColors.ink400, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final v in [50, 100, 200, 500])
                      ActionChip(
                        label: Text('$v EGP'),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                        labelStyle: const TextStyle(color: AppColors.ink300, fontSize: 12),
                        onPressed: () => _amount.text = v.toStringAsFixed(2),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  if (_method == _Method.fingerprint)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Fingerprint payments use the ZK9500 device. Live payment is charged at 10 EGP or more.',
                          style: TextStyle(color: AppColors.ink400, fontSize: 12)),
                      const SizedBox(height: 10),
                    ]),
                  const SizedBox(height: 14),

                  Row(children: [
                    Expanded(child: AppInput(controller: _first, label: 'First name')),
                    const SizedBox(width: 10),
                    Expanded(child: AppInput(controller: _last, label: 'Last name')),
                  ]),
                  const SizedBox(height: 14),
                  AppInput(controller: _phone, label: 'Phone',
                      keyboardType: TextInputType.phone, hint: '+201001234567'),
                  if (_method == _Method.wallet) ...[
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _walletPhone,
                      label: 'Mobile-wallet phone (11 digits)',
                      keyboardType: TextInputType.phone,
                      hint: '01001234567',
                      helper: 'The phone registered with your Vodafone/Etisalat/Orange wallet.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Continue to ${_method == _Method.card ? "card" : _method == _Method.wallet ? "mobile wallet" : "fingerprint"}',
                      onPressed: _submit, loading: _busy, expand: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your wallet will be credited automatically once Paymob confirms the payment.',
                    style: TextStyle(color: AppColors.ink400, fontSize: 12),
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

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.active, required this.onTap, required this.title, required this.sub,
  });
  final bool active;
  final VoidCallback onTap;
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandPrimary.withValues(alpha: 0.1)
              : AppColors.ink950.withValues(alpha: 0.4),
          border: Border.all(
            color: active
                ? AppColors.brandPrimary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
        ]),
      ),
    );
  }
}
