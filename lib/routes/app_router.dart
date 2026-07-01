import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/pages/bank_account_page.dart';
import 'package:wallet/pages/on_boarding_page.dart';

import '../models/api_models.dart';
import '../pages/admin_kyc_review_page.dart';
import '../pages/chat_page.dart';
import '../pages/enable_biometrics_page.dart';
import '../pages/fingerprint_auth_page.dart';
import '../pages/kyc_liveness_page.dart';
import '../pages/kyc_status_page.dart';
import '../pages/kyc_submit_page.dart';
import '../pages/login_page.dart';
import '../pages/merchant_qr_page.dart';
import '../pages/notifications_page.dart';
import '../pages/payment_result_page.dart';
import '../pages/profile_page.dart';
import '../pages/register_page.dart';
import '../pages/report_page.dart';
import '../pages/shell_page.dart';
import '../pages/top_up_page.dart';
import '../pages/transfer_page.dart';
import '../pages/wallet_dashboard_page.dart';
import '../state/providers.dart';
import '../theme/colors.dart';

/// Publicly-reachable paths. Anything else requires auth.
const _public = {
  '/onboarding',
  '/login',
  '/register',
  '/payment-success',
  '/payment-failure',
};

/// Paths that require a particular role beyond authentication.
bool _isAllowed(String path, Role? role) {
  if (path.startsWith('/admin/')) return role == Role.admin;
  if (path.startsWith('/merchant/')) {
    return role == Role.merchant || role == Role.admin;
  }
  return true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Listen to auth changes so the router rebuilds and re-runs the redirect.
  final authListenable = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).value;
      final loc = state.matchedLocation;
      final isPublic = _public.contains(loc);
      final isAuthed = auth?.isAuthenticated ?? false;

      // Not authed + private route → /login
      if (!isAuthed && !isPublic) return '/login';
      // Not authed + on onboarding but already onboarded → /login
      if (!isAuthed && loc == '/onboarding') {
        final hasOnboarded = ref.read(hasOnboardedProvider);
        if (hasOnboarded) return '/login';
      }
      // Authed + on /login or /register → redirect
      if (isAuthed && loc == '/login') return '/';
      if (isAuthed && loc == '/register') return '/';
      // Authed but wrong role
      if (isAuthed && !_isAllowed(loc, auth?.role)) return '/';
      return null;
    },
    routes: [
      // Public routes (no shell, no bottom nav)
      GoRoute(path: '/onboarding', builder: (_, __) => const OnBoardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
          path: '/enable-biometrics',
          builder: (_, __) {
            final pending = ref.read(pendingBiometricCredentialsProvider);
            return EnableBiometricsPage(
              phone: pending?['phone'],
              password: pending?['password'],
            );
          }),
      GoRoute(
          path: '/payment-success',
          builder: (_, __) => const PaymentSuccessPage()),
      GoRoute(
          path: '/payment-failure',
          builder: (_, __) => const PaymentFailurePage()),

      GoRoute(
          path: '/chat',
          builder: (_, state) =>
              ChatPage(userId: state.uri.queryParameters['userId'])),
      // Authenticated app with the bottom-nav shell
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) {
                return const BankAccountPage();
              },
            )
          ]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/', builder: (_, __) => const WalletDashboardPage()),
              GoRoute(
                  path: '/top-up',
                  builder: (_, state) =>
                      TopUpPage(method: state.uri.queryParameters['method'])),
              GoRoute(
                  path: '/fingerprint-auth',
                  builder: (_, state) => FingerprintAuthPage(
                      paymentIntentId:
                          state.uri.queryParameters['paymentIntentId'] ?? '')),
              GoRoute(path: '/report', builder: (_, __) => const ReportPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/transfer', builder: (_, __) => const TransferPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/merchant/qr',
                  builder: (_, __) => const MerchantQrPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/admin/kyc',
                  builder: (_, __) => const AdminKycReviewPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile', builder: (_, __) => const ProfilePage()),
              GoRoute(path: '/kyc', builder: (_, __) => const KycStatusPage()),
              GoRoute(
                  path: '/kyc/submit',
                  builder: (_, __) => const KycSubmitPage()),
              GoRoute(
                  path: '/kyc/liveness',
                  builder: (_, __) => const KycLivenessPage()),
              GoRoute(
                  path: '/notifications',
                  builder: (_, __) => const NotificationsPage()),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('404',
            style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: AppColors.brandAccent)),
        const SizedBox(height: 8),
        Text('Nothing at ${state.matchedLocation}',
            style: const TextStyle(color: AppColors.ink400)),
      ])),
    ),
  );
});

/// Bridge from Riverpod state into a [ChangeNotifier] so go_router refreshes
/// whenever the auth state changes (sign-in, sign-out, refresh failure).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(hasOnboardedProvider, (_, __) => notifyListeners());
  }
  // ignore: unused_field
  final Ref _ref;
}
