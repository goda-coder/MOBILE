import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/onboarding_progress.dart';
import '../widgets/status_pill.dart';

final _summaryProvider = FutureProvider.autoDispose(
  (ref) => ref.read(walletApiProvider).summary(),
);
final _txProvider = FutureProvider.autoDispose(
  (ref) => ref.read(walletApiProvider).transactions(skip: 0, take: 8),
);

class WalletDashboardPage extends ConsumerStatefulWidget {
  const WalletDashboardPage({super.key});
  @override
  ConsumerState<WalletDashboardPage> createState() =>
      _WalletDashboardPageState();
}

class _WalletDashboardPageState extends ConsumerState<WalletDashboardPage> {
  void _syncKyc(bool verified) {
    if (!verified) return;
    final currentAuth = ref.read(authControllerProvider).value;
    if (currentAuth != null && !currentAuth.isKycVerified) {
      ref.read(authControllerProvider.notifier).updateKycStatus(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(_summaryProvider);
    final txs = ref.watch(_txProvider);
    final auth = ref.watch(authControllerProvider).value;
    final setupComplete = auth?.isAccountReadyForFeatures ?? false;

    // Sync KYC status from wallet summary / kycStatusProvider into AuthState
    // so that isAccountReadyForFeatures stays in sync with the backend.
    ref.listen(_summaryProvider, (prev, next) {
      next.whenOrNull(
        data: (s) => _syncKyc(s.isKycVerified),
      );
    });
    // Fallback sync from the KYC status endpoint
    ref.listen(kycStatusProvider, (prev, next) {
      next.whenOrNull(
        data: (status) => _syncKyc(status == 'Verified'),
      );
    });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_summaryProvider);
          ref.invalidate(_txProvider);
          await Future.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('WELCOME BACK',
                          style: TextStyle(
                              color: AppColors.ink400,
                              letterSpacing: 2,
                              fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(auth?.fullName ?? 'there',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ===== Onboarding Progress (shown when setup incomplete) =====
            if (!setupComplete) ...[
              const OnboardingProgress(),
              const SizedBox(height: 16),
            ],

            // ===== Verified status card (shown when setup is complete) =====
            if (setupComplete && auth?.role != Role.admin) ...[
              _VerifiedAccountCard(),
              const SizedBox(height: 16),
            ],

            // ===== Balance + actions =====
            if (setupComplete)
              summary.when(
                data: (s) => BalanceCard(summary: s),
                loading: () => const _BalanceSkeleton(),
                error: (e, _) => ErrorCard(
                    title: 'Could not load balance', message: e.toString()),
              ),
            const SizedBox(height: 12),
            // ===== Recent activity (only when setup complete) =====
            if (setupComplete)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent activity',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      txs.when(
                        data: (list) => list.isEmpty
                            ? const _Empty(
                                text:
                                    'No transactions yet. Send or top up to get started.')
                            : _TxList(txs: list),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (e, _) => ErrorCard(message: e.toString()),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Verified Account Card (shown when setup is complete) =====
class _VerifiedAccountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final ready = auth?.isAccountReadyForFeatures ?? false;
    return Card(
      child: InkWell(
        onTap: () => context.push('/account-setup'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Verified',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? 'Your account is fully verified. You now have access to all wallet features.'
                        : 'Complete the remaining steps to unlock all features.',
                    style:
                        const TextStyle(color: AppColors.ink400, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink400),
          ]),
        ),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.summary,
  });

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BALANCE',
                style: TextStyle(
                    letterSpacing: 2, color: AppColors.ink400, fontSize: 11)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                formatAmount(summary.balanceMinor),
                style: AppTheme.numTextStyle(
                    fontSize: 40, fontWeight: FontWeight.w300),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(summary.currency,
                    style: AppTheme.numTextStyle(
                        fontSize: 16, color: AppColors.ink400)),
              ),
            ]),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Send',
                        icon: Icons.north_east,
                        expand: true,
                        onPressed: () => context.push('/transfer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Support',
                        icon: Icons.chat_bubble,
                        variant: AppButtonVariant.ghost,
                        expand: true,
                        onPressed: () => context.push('/chat'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Report',
                        icon: Icons.receipt_long,
                        variant: AppButtonVariant.ghost,
                        expand: true,
                        onPressed: () => context.push('/report'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList({required this.txs});
  final List<WalletTransaction> txs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: txs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = txs[i];
        final positive = _isPositive(t.kind);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: positive
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.ink700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                positive ? Icons.south_west : Icons.north_east,
                size: 16,
                color: positive ? AppColors.success : AppColors.ink100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.description ?? _kindLabel(t.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(formatRelative(t.createdAt),
                      style: const TextStyle(
                          color: AppColors.ink400, fontSize: 12)),
                ],
              ),
            ),
            Text(
              '${positive ? '+' : '−'}${formatMoney(t.amountMinor, currency: t.currency)}',
              style: AppTheme.numTextStyle(
                fontSize: 14,
                color: positive ? AppColors.success : AppColors.ink100,
              ),
            ),
          ]),
        );
      },
    );
  }

  static bool _isPositive(TxKind k) =>
      k == TxKind.transferIn || k == TxKind.topup || k == TxKind.refund;

  static String _kindLabel(TxKind k) => switch (k) {
        TxKind.transferIn => 'Received',
        TxKind.transferOut => 'Sent',
        TxKind.topup => 'Top-up',
        TxKind.refund => 'Refund',
        TxKind.fee => 'Fee',
        TxKind.unknown => 'Transaction',
      };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink400, fontSize: 13))),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      Card(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    ]);
  }
}
