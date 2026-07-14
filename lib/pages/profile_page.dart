import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/status_pill.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
                child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Full Name', auth?.fullName ?? '—'),
                    _Row('Phone Number', auth?.phoneNumber ?? '—'),
                    _Row('Role', _roleLabel(auth?.role),
                        pill: true, tone: PillTone.info),
                    _Row(
                        'Session',
                        auth?.refreshToken != null &&
                                auth!.refreshToken!.isNotEmpty
                            ? 'Active'
                            : 'None',
                        pill: true,
                        tone: auth?.refreshToken != null &&
                                auth!.refreshToken!.isNotEmpty
                            ? PillTone.ok
                            : PillTone.bad),
                    const SizedBox(height: 14),
                    const _UserActions(),
                  ]),
            )),
            const SizedBox(height: 16),
            const _TransferLimits(),
            const SizedBox(height: 16),
            const _UserSecurity(),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(Role? r) => switch (r) {
        Role.admin => 'Admin',
        Role.merchant => 'Merchant',
        Role.customer => 'Customer',
        null => '—',
      };
}

class _UserSecurity extends ConsumerWidget {
  const _UserSecurity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Security', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ListTile(
          onTap: () => context.push('/change-password'),
          leading: const Icon(Icons.lock_outline),
          contentPadding: EdgeInsets.zero,
          title: const Text("Change password"),
          trailing: const Icon(Icons.chevron_right),
        ),
        if (auth?.hasPin == true)
          ListTile(
            onTap: () => context.push('/reset-pin'),
            leading: const Icon(Icons.pin_outlined),
            contentPadding: EdgeInsets.zero,
            title: const Text("Reset Security PIN"),
            trailing: const Icon(Icons.chevron_right),
          ),
        const SizedBox(
          height: 8.0,
        ),
        AppButton(
          label: 'Sign out',
          variant: AppButtonVariant.danger,
          icon: Icons.logout,
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ]),
    ));
  }
}

class _UserActions extends ConsumerWidget {
  const _UserActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8.0,
          children: [
            Expanded(
              child: AppButton(
                label: 'Account report',
                icon: Icons.receipt_long,
                onPressed: () => context.push('/report'),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AppButton(
                label: 'Contact admin',
                icon: Icons.chat_bubble_outline,
                variant: AppButtonVariant.ghost,
                onPressed: () => context.push('/chat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.pill = false, this.tone});
  final String label, value;
  final bool pill;
  final PillTone? tone;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 12.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
              child: Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.ink400,
                      letterSpacing: 1.5,
                      fontSize: 11))),
          Expanded(
            child: pill
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill(value, tone: tone ?? PillTone.neutral),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.ink100,
                    ),
                    softWrap: true,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransferLimits extends ConsumerWidget {
  const _TransferLimits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitsAsync = ref.watch(transferLimitsProvider);
    return limitsAsync.when(
      data: (limits) {
        if (limits == null) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer Limits',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _LimitCard(
                  title: 'Daily Limit',
                  used: limits.dailyUsed,
                  limit: limits.dailyLimit,
                  remaining: limits.dailyRemaining,
                  resetAt: limits.dailyResetAt,
                ),
                const SizedBox(height: 16),
                _LimitCard(
                  title: 'Monthly Limit',
                  used: limits.monthlyUsed,
                  limit: limits.monthlyLimit,
                  remaining: limits.monthlyRemaining,
                  resetAt: limits.monthlyResetAt,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Transfer Limits',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Center(
                  child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            ],
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({
    required this.title,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  final String title;
  final int used;
  final int limit;
  final int remaining;
  final String resetAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = limit > 0 ? used / limit : 0.0;
    final resetLabel = _formatReset(resetAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink700.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  )),
              Text('${formatAmount(used)} / ${formatAmount(limit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink400,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: percent >= 1.0
                ? AppColors.danger
                : percent >= 0.8
                    ? AppColors.warning
                    : AppColors.brandPrimary,
            backgroundColor: AppColors.ink700,
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Remaining: ${formatAmount(remaining)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: remaining > 0 ? AppColors.ink300 : AppColors.danger,
                  )),
              Text('Resets: $resetLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink400,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReset(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inHours < 24) {
      return 'Tomorrow at 12:00 AM';
    }
    return '${dt.day} ${_months[dt.month - 1]}';
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
