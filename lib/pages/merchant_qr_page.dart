import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class MerchantQrPage extends ConsumerStatefulWidget {
  const MerchantQrPage({super.key});
  @override
  ConsumerState<MerchantQrPage> createState() => _MerchantQrPageState();
}

class _MerchantQrPageState extends ConsumerState<MerchantQrPage> {
  final _amount = TextEditingController();
  final _note   = TextEditingController();
  String? _payload;
  int? _minorShown;

  @override
  void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _generate() async {
    // Check if KYC is verified first
    final isKycVerified = await ref.read(isKycVerifiedProvider.future).catchError((_) => false);
    if (!isKycVerified) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('KYC Verification Required'),
            content: const Text('You must complete your identity verification before you can generate merchant QR codes.'),
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
    if (minor == null || minor <= 0) return;
    final merchantId = ref.read(authControllerProvider).value?.userId ?? 'unknown';
    // Same payload shape as the React app — scanner side parses identically.
    final uri = Uri(
      scheme: 'wallet-pay',
      host: merchantId,
      queryParameters: {
        'amountMinor': minor.toString(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'v': '1',
      },
    );
    setState(() {
      _payload = uri.toString();
      _minorShown = minor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              "Show the customer this QR. They scan it from their wallet to pay you.",
              style: TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const SizedBox(height: 14),
                AppInput(controller: _note, label: 'Note (optional)',
                    hint: "What's this for?"),
                const SizedBox(height: 16),
                AppButton(label: 'Generate QR', onPressed: _generate,
                    icon: Icons.qr_code),
              ]),
            )),

            if (_payload != null && _minorShown != null) ...[
              const SizedBox(height: 16),
              Card(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _payload!,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1A1A1A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('REQUESTING',
                    style: TextStyle(color: AppColors.ink400, letterSpacing: 2, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(formatMoney(_minorShown!),
                      style: numTextStyle(fontSize: 24)),
                  if (_note.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_note.text.trim(),
                        style: const TextStyle(color: AppColors.ink400, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Text(_payload!,
                      textAlign: TextAlign.center,
                      style: numTextStyle(color: AppColors.ink500, fontSize: 10)),
                ]),
              )),
            ],
          ]),
        ),
      ),
    );
  }
}
