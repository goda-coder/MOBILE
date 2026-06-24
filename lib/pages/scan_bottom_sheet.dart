import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/status_pill.dart';

class _Parsed {
  _Parsed(this.merchantId, this.amountMinor, this.note);
  final String merchantId;
  final int amountMinor;
  final String? note;
}

class ScanBottomSheet extends ConsumerStatefulWidget {
  const ScanBottomSheet({super.key});
  @override
  ConsumerState<ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends ConsumerState<ScanBottomSheet> {
  _Parsed? _parsed;
  String? _error;
  bool _paying = false;

  void _onScan(String payload) {
    try {
      final uri = Uri.parse(payload);
      if (uri.scheme != 'wallet-pay') {
        throw const FormatException('Not a wallet payment QR.');
      }
      final merchantId =
          uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
      final amountMinor =
          int.tryParse(uri.queryParameters['amountMinor'] ?? '');
      if (merchantId.isEmpty || amountMinor == null || amountMinor <= 0) {
        throw const FormatException('QR is missing required fields.');
      }
      setState(() => _parsed =
          _Parsed(merchantId, amountMinor, uri.queryParameters['note']));
    } catch (e) {
      setState(() => _error = e is FormatException ? e.message : 'Invalid QR.');
    }
  }

  Future<void> _pay() async {
    final p = _parsed;
    if (p == null) return;

    final isKycVerified =
        await ref.read(isKycVerifiedProvider.future).catchError((_) => false);
    if (!isKycVerified) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('KYC Verification Required'),
            content: const Text(
                'You must complete your identity verification before you can make payments.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
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

    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final reference = 'qr-${DateTime.now().microsecondsSinceEpoch}';
      final r = await ref.read(walletApiProvider).transfer(
            recipientIdentifier: p.merchantId,
            amountMinor: p.amountMinor,
            reference: reference,
            description: p.note,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Paid. New balance: ${formatMoney(r.newBalanceMinor)}'),
        backgroundColor: AppColors.success.withValues(alpha: 0.25),
      ));
      Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not complete payment.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.ink500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Scan to pay',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Point your camera at a merchant's QR. We confirm the amount before transferring.",
                style: TextStyle(color: AppColors.ink400),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorCard(message: _error!),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _parsed == null
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: AppQrScanner(onScan: _onScan),
                          ),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              const Text("YOU'LL PAY",
                                  style: TextStyle(
                                      color: AppColors.ink400,
                                      letterSpacing: 2,
                                      fontSize: 11)),
                              const SizedBox(height: 8),
                              Text(formatMoney(_parsed!.amountMinor),
                                  style: AppTheme.numTextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w300)),
                              if (_parsed!.note != null) ...[
                                const SizedBox(height: 8),
                                Text('"${_parsed!.note!}"',
                                    style: const TextStyle(
                                        color: AppColors.ink300,
                                        fontStyle: FontStyle.italic)),
                              ],
                              const SizedBox(height: 12),
                              Text('to ${_parsed!.merchantId}',
                                  style: AppTheme.numTextStyle(
                                      color: AppColors.ink400, fontSize: 11)),
                              const SizedBox(height: 20),
                              Row(children: [
                                Expanded(
                                    child: AppButton(
                                  label: 'Confirm & pay',
                                  onPressed: _pay,
                                  loading: _paying,
                                  expand: true,
                                )),
                                const SizedBox(width: 8),
                                AppButton(
                                  label: 'Scan again',
                                  variant: AppButtonVariant.ghost,
                                  onPressed: () => setState(() {
                                    _parsed = null;
                                    _error = null;
                                  }),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showScanBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const ScanBottomSheet(),
  );
}
