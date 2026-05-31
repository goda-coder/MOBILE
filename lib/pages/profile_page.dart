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
      appBar: AppBar(title: const Text('Your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Account details and session controls.',
                style: TextStyle(color: AppColors.ink400)),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Row('Email', auth?.email ?? '—'),
                _Row('User ID', auth?.userId ?? '—', mono: true),
                _Row('Role', _roleLabel(auth?.role), pill: true,
                    tone: PillTone.info),
                _Row('Session',
                    auth?.refreshToken != null && auth!.refreshToken!.isNotEmpty
                        ? 'Active' : 'None',
                    pill: true,
                    tone: auth?.refreshToken != null && auth!.refreshToken!.isNotEmpty
                        ? PillTone.ok : PillTone.bad),
              ]),
            )),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Security', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text(
                  "Need to change your password or revoke all sessions? Those endpoints exist on the backend; wire them up to this page when ready.",
                  style: TextStyle(color: AppColors.ink400, fontSize: 13),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Account report',
                  icon: Icons.receipt_long,
                  onPressed: () => context.push('/report'),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Contact admin',
                  icon: Icons.chat_bubble_outline,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.push('/chat'),
                ),
                const SizedBox(height: 14),
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
            )),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(Role? r) => switch (r) {
        Role.admin    => 'Admin',
        Role.merchant => 'Merchant',
        Role.customer => 'Customer',
        null          => '—',
      };
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.mono = false, this.pill = false, this.tone});
  final String label, value;
  final bool mono, pill;
  final PillTone? tone;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90,
            child: Text(label.toUpperCase(),
              style: const TextStyle(color: AppColors.ink400, letterSpacing: 1.5, fontSize: 11))),
          Expanded(
            child: pill
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill(value, tone: tone ?? PillTone.neutral),
                  )
                : Text(value,
                    style: TextStyle(
                      color: AppColors.ink100,
                      fontFamily: mono ? 'monospace' : null,
                      fontSize: mono ? 12 : 14,
                    ),
                    softWrap: true,
                  ),
          ),
        ],
      ),
    );
  }
}
