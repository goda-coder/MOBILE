import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/fraud_result.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';

class FraudHighRiskPage extends StatelessWidget {
  const FraudHighRiskPage({super.key, this.result});

  final FraudCheckResult? result;

  @override
  Widget build(BuildContext context) {
    final reasons = result?.reasons ?? [];
    final probability = result?.probability ?? 0;

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
                      color: AppColors.danger.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded,
                        color: AppColors.danger, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('High Risk Transaction',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'The transaction has been flagged as high-risk and has been cancelled for your security.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.ink400, fontSize: 14, height: 1.4),
                  ),
                  if (probability > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Fraud probability: ${probability.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...reasons.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('[${r.code}] ',
                                  style: const TextStyle(
                                      color: AppColors.ink400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Expanded(
                                child: Text(r.text,
                                    style: const TextStyle(
                                        color: AppColors.ink400,
                                        fontSize: 12,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Back to Wallet',
                      onPressed: () => context.go('/'),
                      expand: true,
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
