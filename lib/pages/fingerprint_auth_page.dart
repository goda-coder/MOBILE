import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

class FingerprintAuthPage extends ConsumerStatefulWidget {
  const FingerprintAuthPage({super.key, required this.paymentIntentId});

  final String paymentIntentId;

  @override
  ConsumerState<FingerprintAuthPage> createState() => _FingerprintAuthPageState();
}

class _FingerprintAuthPageState extends ConsumerState<FingerprintAuthPage> {
  PaymentIntentStatusResponse? _status;
  String? _error;
  bool _busy = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final status = await ref.read(paymentsApiProvider).paymentIntentStatus(widget.paymentIntentId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
      });

      if (status.status == 'COMPLETED') {
        if (mounted) context.go('/payment-success');
        return;
      }
      if (status.status == 'FAILED') {
        if (mounted) context.go('/payment-failure');
        return;
      }
    } on ApiError catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Unable to fetch fingerprint payment status.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final intentId = widget.paymentIntentId;

    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fingerprint payment is pending device authentication.',
                style: TextStyle(color: AppColors.ink400, fontSize: 14)),
            const SizedBox(height: 12),
            if (_status != null) ...[
              Text('Order reference: ${_status!.orderReference}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('Status: ${_status!.status}', style: const TextStyle(color: AppColors.brandPrimary)),
              const SizedBox(height: 8),
              if (_status!.paymentDevice != null)
                Text('Device: ${_status!.paymentDevice}', style: const TextStyle(color: AppColors.ink400)),
              if (_status!.paymentNote != null) ...[
                const SizedBox(height: 8),
                Text(_status!.paymentNote!, style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorCard(message: _error!),
            ],
            const SizedBox(height: 24),
            const Text(
              'Keep the app open and authenticate with the ZK9500 device. The payment will complete automatically once the fingerprint is verified.',
              style: TextStyle(color: AppColors.ink400, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _busy ? 'Checking status…' : 'Refresh status',
                onPressed: _busy ? null : _refreshStatus,
                loading: _busy,
                expand: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('Payment intent: $intentId', style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
