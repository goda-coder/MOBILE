import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_guards.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

final _kycStatusProvider = FutureProvider.autoDispose(
  (ref) => ref.read(kycApiProvider).myStatus(),
);

class AccountSetupPage extends ConsumerWidget {
  const AccountSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final kycAsync = ref.watch(_kycStatusProvider);
    final ready = AuthGuards.canAccessWallet(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Setup'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (ready ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(ready ? Icons.verified : Icons.shield_outlined,
                  color: ready ? AppColors.success : AppColors.warning,
                  size: 36),
            ),
            const SizedBox(height: 20),
            Column(children: [
              Text(
                ready ? 'Account Verified' : 'Account Setup Required',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                ready
                    ? 'Your account is fully verified. You now have access to all wallet features.'
                    : 'Complete the remaining steps below to unlock all wallet features.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink400, fontSize: 14),
              ),
            ]),
            const SizedBox(height: 28),
            _SetupTile(
              icon: Icons.lock_outline,
              title: 'Create Security PIN',
              subtitle: 'Required to sign in and confirm transactions.',
              statusText: auth?.hasPin == true ? 'Completed' : 'Pending',
              statusTone: auth?.hasPin == true ? PillTone.ok : PillTone.bad,
              onAction: auth?.hasPin ?? false
                  ? null
                  : () => context.push('/create-pin'),
              actionLabel: auth?.hasPin == true ? 'Update' : 'Set up',
            ),
            const SizedBox(height: 12),
            kycAsync.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
              error: (e, _) => ErrorCard(message: e.toString()),
              data: (kyc) => _SetupTile(
                icon: Icons.verified_user_outlined,
                title: 'Complete KYC Verification',
                subtitle: 'Verify your identity to start transacting.',
                statusText: kyc.status == 'Verified' ? 'Completed' : kyc.status,
                statusTone: kyc.status == 'Verified'
                    ? PillTone.ok
                    : kyc.status == 'Rejected'
                        ? PillTone.bad
                        : PillTone.neutral,
                onAction: () => context.push('/kyc'),
                actionLabel: kyc.status == 'None'
                    ? 'Start'
                    : kyc.status == 'Verified'
                        ? 'View'
                        : 'View status',
              ),
            ),
            const SizedBox(height: 24),
            if (ready)
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Go to wallet',
                  onPressed: () => context.go('/'),
                  expand: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusTone,
    required this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusText;
  final PillTone statusTone;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      StatusPill(statusText, tone: statusTone),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.ink400, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// 581161 
