import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

final _summaryProvider = FutureProvider.autoDispose(
  (ref) => ref.read(walletApiProvider).summary(),
);
final _txProvider = FutureProvider.autoDispose(
  (ref) => ref.read(walletApiProvider).transactions(skip: 0, take: 8),
);

class WalletDashboardPage extends ConsumerWidget {
  const WalletDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider);
    final txs = ref.watch(_txProvider);
    final auth = ref.watch(authControllerProvider).value;

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
                if (summary.hasValue)
                  StatusPill(summary.value!.kycStatus,
                      tone: kycTone(summary.value!.kycStatus)),
              ],
            ),
            // ---- Bento row ----

            const SizedBox(height: 20),
            summary.when(
              data: (s) => _BentoRow(summary: s),
              loading: () => const _BalanceSkeleton(),
              error: (e, _) => ErrorCard(
                  title: 'Could not load balance', message: e.toString()),
            ),
            const SizedBox(height: 12),

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

class _BentoRow extends StatelessWidget {
  const _BentoRow({required this.summary});
  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(spacing: 12.0, children: [
      // Identity tile
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: summary.isKycVerified
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  summary.isKycVerified
                      ? Icons.verified
                      : Icons.shield_outlined,
                  color: summary.isKycVerified
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        summary.isKycVerified
                            ? 'Verified'
                            : 'Identity not verified',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      summary.isKycVerified
                          ? 'Full features unlocked.'
                          : 'Verify to unlock higher limits.',
                      style: const TextStyle(
                          color: AppColors.ink400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: summary.isKycVerified ? 'View' : 'Verify',
                variant: summary.isKycVerified
                    ? AppButtonVariant.ghost
                    : AppButtonVariant.primary,
                onPressed: () => context.push('/kyc'),
              ),
            ],
          ),
        ),
      ),
      // Big balance tile
      BalanceCard(summary: summary),
    ]);
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
