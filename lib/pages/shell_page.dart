import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import 'scan_bottom_sheet.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.branchIdx);
  final String label;
  final IconData icon;
  final int branchIdx;
}

class ShellPage extends ConsumerWidget {
  const ShellPage({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final role = auth?.role;

    final branchIndices = <int>[
      0, // Wallet
      1, // Send
      if (role == Role.merchant || role == Role.admin) 2, // Receive
      if (role == Role.admin) 3, // Admin
      4, // Me
    ];

    final tabs = <_Tab>[
      const _Tab('Wallet', Icons.account_balance_wallet_outlined, 0),
      const _Tab('Send', Icons.send_outlined, 1),
      if (role == Role.merchant || role == Role.admin)
        const _Tab('Receive', Icons.qr_code_2_outlined, 2),
      if (role == Role.admin)
        const _Tab('Admin', Icons.admin_panel_settings_outlined, 3),
      const _Tab('Me', Icons.person_outline, 4),
    ];

    final currentBranch = navigationShell.currentIndex;
    final visualIdx = branchIndices.indexOf(currentBranch);
    final idx = visualIdx >= 0 ? visualIdx : 0;

    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
        body: navigationShell,
        floatingActionButton: location == '/' || location == '/home'
            ? FloatingActionButton(
                onPressed: () => showScanBottomSheet(context),
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.qr_code_scanner),
              )
            : null,
        bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) =>
                navigationShell.goBranch(tabs[i].branchIdx),
            destinations: tabs
                .map((tab) => NavigationDestination(
                    icon: Icon(tab.icon), label: tab.label))
                .toList()));
  }
}
