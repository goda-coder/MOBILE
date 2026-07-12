import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
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
            const UserLimits(limits: [0.5, 0.5]),
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
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Security', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ListTile(
          onTap: () {},
          leading: const Icon(Icons.lock_outline),
          contentPadding: EdgeInsets.zero,
          title: const Text("Change password"),
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

class UserLimits extends StatelessWidget {
  const UserLimits({super.key, required this.limits});
  final List<double> limits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12.0,
              children: [
                Text(
                  "Wallet Limit",
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold),
                ),
                const UserLimitSection(
                  title: "daily",
                  currentUsage: 0,
                  upperLimit: 5000.0,
                ),
                const UserLimitSection(
                  title: "monthly",
                  currentUsage: 0,
                  upperLimit: 20000.0,
                ),
              ],
            ),
            const SizedBox(
              height: 24.0,
            ),
          ])),
    );
  }
}

class UserLimitSection extends StatelessWidget {
  const UserLimitSection(
      {super.key,
      required this.title,
      required this.upperLimit,
      required this.currentUsage});

  final String title;
  final double upperLimit;
  final double currentUsage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (currentUsage / upperLimit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4.0,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            Text(
              "${(percent * 100).toStringAsFixed(0)}%",
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        Column(
          spacing: 8.0,
          children: [
            LinearProgressIndicator(
              value: percent,
              minHeight: 6.0,
              borderRadius: BorderRadius.circular(999),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$currentUsage EG",
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: .6)),
                ),
                Text(
                  "$upperLimit EG",
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: .6)),
                )
              ],
            ),
          ],
        ),
      ],
    );
  }
}
