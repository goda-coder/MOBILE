import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';

/// Centralized KYC verification guard for money-moving UI actions.
///
/// Every protected action should call [KycGuard.ensureVerified] and abort when
/// it returns `false`. The backend remains the hard, unbypassable enforcement;
/// this guard is a fail-closed UX layer that fetches a fresh status and routes
/// the user to `/kyc` with a status-appropriate message.
class KycGuard {
  const KycGuard._();

  static const String _route = '/kyc';

  /// Returns `true` only when the acting user's KYC status is exactly
  /// `Verified`. On any other status (or a status-fetch failure) it shows a
  /// dialog and returns `false`.
  static Future<bool> ensureVerified(
      BuildContext context, WidgetRef ref) async {
    String status;
    try {
      // Fetch a FRESH status to avoid acting on a stale cached `Verified`.
      final summary = await ref.read(walletApiProvider).summary();
      status = summary.kycStatus;
    } catch (_) {
      // Fail closed: never let an unknown status through the UI.
      if (context.mounted) {
        await _showDialog(
          context,
          title: 'Could not verify your KYC status',
          body: 'We were unable to confirm your identity verification status. '
              'Please check your connection and try again.',
          actionLabel: null,
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
        );
        break;
      case 'Rejected':
        await _showDialog(
          context,
          title: 'Verification rejected',
          body: 'Your verification was not approved. Please resubmit your '
              'identity documents to continue.',
          actionLabel: 'Resubmit',
        );
        break;
      case 'None':
      default:
        await _showDialog(
          context,
          title: 'Identity verification required',
          body: 'Verify your identity to continue.',
          actionLabel: 'Verify now',
        );
        break;
    }
    return false;
  }

  /// Shows a status dialog. When [actionLabel] is non-null, the primary button
  /// dismisses the dialog and navigates to `/kyc`.
  static Future<void> _showDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String? actionLabel,
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
          if (actionLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (ctx.mounted) ctx.push(_route);
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
