import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../widgets/app_button.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});
  @override
  Widget build(BuildContext context) => _Result(
        success: true,
        title: 'Payment received',
        body: "Your wallet will reflect the new balance once Paymob's webhook confirms the transaction.",
      );
}

class PaymentFailurePage extends StatelessWidget {
  const PaymentFailurePage({super.key});
  @override
  Widget build(BuildContext context) => _Result(
        success: false,
        title: 'Payment did not complete',
        body: 'No funds were taken. You can try again, or use a different payment method.',
      );
}

class _Result extends StatelessWidget {
  const _Result({required this.success, required this.title, required this.body});
  final bool success;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.danger;
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
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(success ? Icons.check : Icons.close,
                        color: color, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.ink400, fontSize: 14)),
                  const SizedBox(height: 24),
                  Wrap(spacing: 8, children: [
                    AppButton(
                      label: success ? 'Back to wallet' : 'Try again',
                      onPressed: () => context.go(success ? '/' : '/top-up'),
                    ),
                    AppButton(
                      label: success ? 'Top up again' : 'Back to wallet',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.go(success ? '/top-up' : '/'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
