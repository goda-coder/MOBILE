import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

/// Reusable onboarding progress widget showing PIN + KYC status.
/// Displays progress percentage, step statuses, locked features info,
/// and a CTA to navigate to the full setup flow.
class OnboardingProgress extends ConsumerWidget {
  const OnboardingProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final pinDone = auth?.hasPin ?? false;
    final kycAsync = ref.watch(kycStatusProvider);
    final kycStatus = kycAsync.value ?? 'None';
    final kycDone = kycStatus == 'Verified';
    final completedSteps = (pinDone ? 1 : 0) + (kycDone ? 1 : 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Complete Your Account Setup',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$completedSteps of 2 steps completed',
                        style: const TextStyle(
                            color: AppColors.ink400, fontSize: 12)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completedSteps / 2,
                backgroundColor: AppColors.ink700,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedSteps == 2
                      ? AppColors.success
                      : AppColors.brandPrimary,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),
            _StepRow(
              number: 1,
              title: 'Create Security PIN',
              subtitle: 'Required for sign-in and transaction confirmation',
              done: pinDone,
              active: !pinDone,
            ),
            const SizedBox(height: 12),
            _StepRow(
              number: 2,
              title: 'Complete KYC Verification',
              subtitle: kycDone
                  ? 'Identity verified'
                  : kycStatus == 'Pending'
                      ? 'Verification in review'
                      : kycStatus == 'Rejected'
                          ? 'Verification rejected — please resubmit'
                          : 'Verify your identity to start transacting',
              done: kycDone,
              active: pinDone && !kycDone,
              statusOverride: kycStatus == 'Pending'
                  ? 'In Review'
                  : kycStatus == 'Rejected'
                      ? 'Rejected'
                      : null,
              statusToneOverride: kycStatus == 'Rejected'
                  ? PillTone.bad
                  : kycStatus == 'Pending'
                      ? PillTone.warn
                      : null,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warningBorder.withValues(alpha: 0.5)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lock_outline,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 6),
                    Text('Features locked until setup is complete',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningText)),
                  ]),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _LockedChip('Send Money'),
                      _LockedChip('Receive Money'),
                      _LockedChip('Wallet Balance'),
                      _LockedChip('Payments'),
                      _LockedChip('Transfers'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: completedSteps == 0 ? 'Start setup' : 'Continue setup',
                icon: Icons.arrow_forward,
                onPressed: () => context.push('/account-setup'),
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  const _LockedChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ink700.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.ink400, fontSize: 11)),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    this.active = false,
    this.statusOverride,
    this.statusToneOverride,
  });
  final int number;
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final String? statusOverride;
  final PillTone? statusToneOverride;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : active
            ? AppColors.brandPrimary
            : AppColors.ink400;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: done
              ? AppColors.success.withValues(alpha: 0.15)
              : active
                  ? AppColors.brandPrimary.withValues(alpha: 0.15)
                  : AppColors.ink700,
          shape: BoxShape.circle,
          border: active && !done
              ? Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.4))
              : null,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 18, color: AppColors.success)
              : Text('$number',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: done ? AppColors.ink100 : AppColors.ink200)),
                ),
                StatusPill(
                  statusOverride ?? (done ? 'Completed' : 'Pending'),
                  tone: statusToneOverride ??
                      (done ? PillTone.ok : PillTone.neutral),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
          ],
        ),
      ),
    ]);
  }
}
