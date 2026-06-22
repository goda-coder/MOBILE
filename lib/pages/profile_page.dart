import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_models.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../widgets/app_button.dart';
import '../widgets/inline_alert.dart';
import '../widgets/status_pill.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final role = auth?.role;

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
            const Text('Account details and session controls.',
                style: TextStyle(color: AppColors.ink400)),
            const SizedBox(height: 16),
            Card(
                child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Phone Number', auth?.phoneNumber ?? '—'),
                    _Row('User ID', auth?.userId ?? '—', mono: true),
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
                  ]),
            )),
            if (role != null && role == Role.merchant ||
                role == Role.admin) ...[
              const SizedBox(height: 16),
              const BiometricPaymentPanel(),
            ],
            const SizedBox(height: 16),
            Card(
                child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Security',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                      "Need to change your password or revoke all sessions? Those endpoints exist on the backend; wire them up to this page when ready.",
                      style: TextStyle(color: AppColors.ink400, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Sign out',
                      variant: AppButtonVariant.danger,
                      icon: Icons.logout,
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
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
        Role.admin => 'Admin',
        Role.merchant => 'Merchant',
        Role.customer => 'Customer',
        null => '—',
      };
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value,
      {this.mono = false, this.pill = false, this.tone});
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
          SizedBox(
              width: 90,
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

class BiometricPaymentPanel extends ConsumerWidget {
  const BiometricPaymentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(biometricPaymentServiceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Biometric Payment Server",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _StatusRow(
              label: "Server",
              active: state.serverRunning,
              activeLabel: "Running",
              inactiveLabel: "Stopped",
            ),
            const SizedBox(height: 6),
            _StatusRow(
              label: "Merchant",
              active: state.merchantConnected,
              activeLabel: "Connected",
              inactiveLabel: "Disconnected",
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              InlineAlert(
                message: state.errorMessage!,
                type: AlertType.danger,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: AppButton(
                    label: state.serverRunning ? "Stop Server" : "Start Server",
                    icon: state.serverRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    variant: state.serverRunning
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    loading: state.isProcessing,
                    onPressed: state.isProcessing
                        ? null
                        : () async {
                            if (state.serverRunning) {
                              await ref
                                  .read(
                                      biometricPaymentServiceProvider.notifier)
                                  .stopServer();
                            } else {
                              await ref
                                  .read(
                                      biometricPaymentServiceProvider.notifier)
                                  .startServer();
                            }
                          },
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: "Request Payment",
                    icon: Icons.payment,
                    variant: AppButtonVariant.ghost,
                    onPressed: state.serverRunning
                        ? () => context.push('/merchant/payment-request')
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  final String label;
  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          StatusPill(
            active ? activeLabel : inactiveLabel,
            tone: active ? PillTone.ok : PillTone.neutral,
          ),
        ],
      ),
    );
  }
}
