import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

class ShellPage extends ConsumerWidget {
  const ShellPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final role = auth?.role;

    final tabs = <_Tab>[
      const _Tab('Wallet', Icons.account_balance_wallet_outlined, '/'),
      const _Tab('Send',   Icons.send_outlined,                   '/transfer'),
      const _Tab('Scan',   Icons.qr_code_scanner_outlined,        '/scan'),
      if (role == Role.merchant || role == Role.admin)
        const _Tab('Receive', Icons.qr_code_2_outlined,           '/merchant/qr'),
      if (role == Role.admin)
        const _Tab('Admin',   Icons.admin_panel_settings_outlined, '/admin/kyc'),
      const _Tab('Me',     Icons.person_outline,                  '/profile'),
    ];

    final location = GoRouterState.of(context).matchedLocation;
    int currentIdx = tabs.indexWhere((t) =>
        t.path == '/' ? location == '/' : location.startsWith(t.path));
    if (currentIdx < 0) currentIdx = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIdx,
        onTap: (i) => context.go(tabs[i].path),
        items: [
          for (final t in tabs)
            BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
