import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../api/api_client.dart';
import '../models/fraud_result.dart';
import '../models/transfer_data.dart';
import '../state/providers.dart';
import '../theme/colors.dart';

class FraudDetectionGuardPage extends ConsumerStatefulWidget {
  const FraudDetectionGuardPage({super.key, required this.data});
  final TransferData data;

  @override
  ConsumerState<FraudDetectionGuardPage> createState() => _FraudDetectionGuardPageState();
}

class _FraudDetectionGuardPageState extends ConsumerState<FraudDetectionGuardPage> {
  static const _steps = [
    'Processing activity...',
    'Processing transaction...',
    'Processing location...',
  ];

  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  void _startProcessing() {
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      } else {
        _timer?.cancel();
        _runFraudCheck();
      }
    });
  }

  Future<void> _runFraudCheck() async {
    try {
      final result = await ref.read(fraudApiProvider).checkTransfer(widget.data);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      switch (result.riskLevel) {
        case 'LOW':
          context.pushReplacement('/recipient-confirmation', extra: widget.data);
        case 'MEDIUM':
          await _handleMediumRisk(result);
        case 'HIGH':
          context.pushReplacement('/fraud-high-risk', extra: result);
        default:
          context.pushReplacement('/recipient-confirmation', extra: widget.data);
      }
    } on ApiError {
      if (mounted) context.pushReplacement('/recipient-confirmation', extra: widget.data);
    }
  }

  Future<void> _handleMediumRisk(FraudCheckResult result) async {
    final reasons = result.reasons;
    final warningText = reasons.isNotEmpty
        ? reasons.map((r) => '• ${r.text}').join('\n\n')
        : 'The transaction looks unusual.';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unusual Activity Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Risk: ${result.probability.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Text(warningText, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
            const Text('Verify with biometrics to proceed.',
                style: TextStyle(color: AppColors.ink400, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify')),
        ],
      ),
    );

    if (proceed != true || !mounted) {
      if (mounted) context.go('/');
      return;
    }

    final localAuth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated = await localAuth.authenticate(
        localizedReason: 'Verify your identity to proceed with this transaction',
      );
    } catch (_) {}

    if (!mounted) return;

    if (authenticated) {
      context.pushReplacement('/recipient-confirmation', extra: widget.data);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric verification failed. Transaction cancelled.')),
        );
        context.go('/');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.brandPrimary, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('Fraud Detection',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) {
                      final filled = i <= _currentStep;
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? AppColors.brandPrimary
                              : AppColors.ink500,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _steps[_currentStep >= _steps.length ? _steps.length - 1 : _currentStep],
                      key: ValueKey(_currentStep),
                      style: const TextStyle(
                          color: AppColors.ink300, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brandSecondary),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
