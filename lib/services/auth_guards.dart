import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';

/// Centralized authorization guards for feature access control.
///
/// All protected features must go through these guards before allowing
/// the operation. Guards never navigate unexpectedly — they show dialogs
/// explaining what's needed and provide CTAs.
class AuthGuards {
  const AuthGuards._();

  // -- Pure helpers (no side effects) --

  static bool hasSecurityPin(AuthState? auth) => auth?.hasPin ?? false;

  static bool isKycVerified(AuthState? auth) => auth?.isKycVerified ?? false;

  static bool canAccessWallet(AuthState? auth) =>
      hasSecurityPin(auth) && isKycVerified(auth);

  static bool canSendMoney(AuthState? auth) => canAccessWallet(auth);

  static bool canReceiveMoney(AuthState? auth) => canAccessWallet(auth);

  static bool canViewBalance(AuthState? auth) => canAccessWallet(auth);

  // -- UI guards (show dialogs, return bool) --

  /// Checks that the user has both Security PIN created AND KYC verified.
  /// Shows a dialog listing the missing steps with a CTA to resolve them.
  /// Returns `true` only when both are satisfied.
  static Future<bool> requireWalletAccess(
      BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider).value;
    if (auth == null) return false;
    if (auth.isAdmin) return true;

    final missing = <String>[];

    if (!auth.hasPin) {
      missing.add('Create Security PIN — Pending');
    }

    String kycStatus = 'None';
    try {
      final summary = await ref.read(walletApiProvider).summary();
      kycStatus = summary.kycStatus;
      await ref
          .read(authControllerProvider.notifier)
          .updateKycStatus(summary.isKycVerified);
    } catch (_) {
      if (context.mounted) {
        await _showDialog(
          context,
          title: 'Could not verify your status',
          body: 'Please check your connection and try again.',
          actionLabel: null,
          actionRoute: null,
        );
      }
      return false;
    }

    if (kycStatus != 'Verified') {
      missing.add('Complete KYC Verification — $kycStatus');
    }

    if (missing.isEmpty) return true;
    if (!context.mounted) return false;

    final body = 'These features are unavailable until you complete the following:\n\n${missing.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}';

    await _showDialog(
      context,
      title: 'Account Setup Required',
      body: body,
      actionLabel: 'Go to setup',
      actionRoute: '/',
    );
    return false;
  }

  /// Checks that KYC status is exactly 'Verified'.
  /// Shows a status-appropriate dialog and returns `false` otherwise.
  static Future<bool> requireKycVerified(
      BuildContext context, WidgetRef ref) async {
    String status;
    try {
      final summary = await ref.read(walletApiProvider).summary();
      status = summary.kycStatus;
    } catch (_) {
      if (context.mounted) {
        await _showDialog(
          context,
          title: 'Could not verify your KYC status',
          body: 'We were unable to confirm your identity verification status. '
              'Please check your connection and try again.',
          actionLabel: null,
          actionRoute: null,
        );
      }
      return false;
    }

    if (status == 'Verified') return true;
    if (!context.mounted) return false;

    switch (status) {
      case 'Pending':
        await _showDialog(
          context,
          title: 'Verification in review',
          body: 'Your submission is being reviewed. '
              "You'll be able to transact once approved.",
          actionLabel: 'View status',
          actionRoute: '/kyc',
        );
        break;
      case 'Rejected':
        await _showDialog(
          context,
          title: 'Verification rejected',
          body: 'Your verification was not approved. Please resubmit your '
              'identity documents to continue.',
          actionLabel: 'Resubmit',
          actionRoute: '/kyc',
        );
        break;
      case 'None':
      default:
        await _showDialog(
          context,
          title: 'Identity verification required',
          body: 'Verify your identity to continue.',
          actionLabel: 'Verify now',
          actionRoute: '/kyc',
        );
        break;
    }
    return false;
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String? actionLabel,
    required String? actionRoute,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (actionLabel != null && actionRoute != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (ctx.mounted) ctx.push(actionRoute);
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
