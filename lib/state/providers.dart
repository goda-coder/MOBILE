import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/chat_api.dart';
import '../api/kyc_api.dart';
import '../api/payments_api.dart';
import '../api/wallet_api.dart';
import '../models/api_models.dart';

// -- Config ----------------------------------------------------------
/// Override with --dart-define=API_BASE_URL=https://api.example.com
const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

final String _defaultBaseUrl = _envBaseUrl.isNotEmpty
    ? _envBaseUrl
    : (kIsWeb
        ? '${Uri.base.scheme == 'https' ? 'https' : 'http'}://${Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost'}:8081'
        : 'http://10.0.2.2:8081');

final apiBaseUrlProvider = Provider<String>((_) => _defaultBaseUrl);

// -- Storage + client ------------------------------------------------
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  ),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.read(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ref.read(apiBaseUrlProvider),
    tokens: ref.read(tokenStoreProvider),
  ),
);

// -- Per-domain API wrappers -----------------------------------------
final authApiProvider = Provider((ref) => AuthApi(ref.read(apiClientProvider)));
final walletApiProvider =
    Provider((ref) => WalletApi(ref.read(apiClientProvider)));
final chatApiProvider = Provider((ref) => ChatApi(ref.read(apiClientProvider)));
final kycApiProvider = Provider((ref) => KycApi(ref.read(apiClientProvider)));
final paymentsApiProvider =
    Provider((ref) => PaymentsApi(ref.read(apiClientProvider)));
final adminApiProvider =
    Provider((ref) => AdminApi(ref.read(apiClientProvider)));

// -- Auth state ------------------------------------------------------
class AuthState {
  AuthState(
      {this.accessToken,
      this.refreshToken,
      this.role,
      this.phoneNumber,
      this.userId});
  final String? accessToken;
  final String? refreshToken;
  final Role? role;
  final String? phoneNumber;
  final String? userId;
  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final s = await ref.read(tokenStoreProvider).getSession();
    return AuthState(
      accessToken: s['access'],
      refreshToken: s['refresh'],
      role: s['role'] == null ? null : parseRole(s['role']!),
      phoneNumber: s['phoneNumber'],
      userId: s['userId'],
    );
  }

  Future<void> signIn(String phoneNumber, String password) async {
    state = const AsyncLoading();
    try {
      final r = await ref.read(authApiProvider).login(phoneNumber, password);
      await ref.read(tokenStoreProvider).setSession(
            access: r.accessToken,
            refresh: r.refreshToken,
            role: r.role.name,
            phoneNumber: r.phoneNumber,
            userId: r.userId,
          );
      state = AsyncData(AuthState(
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        role: r.role,
        phoneNumber: r.phoneNumber,
        userId: r.userId,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signInWithFingerprint(String fingerprintId) async {
    state = const AsyncLoading();
    try {
      final r = await ref.read(authApiProvider).loginWithFingerprint(
            fingerprintId: fingerprintId,
            matched: true,
          );
      await ref.read(tokenStoreProvider).setSession(
            access: r.accessToken,
            refresh: r.refreshToken,
            role: r.role.name,
            phoneNumber: r.phoneNumber,
            userId: r.userId,
          );
      state = AsyncData(AuthState(
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        role: r.role,
        phoneNumber: r.phoneNumber,
        userId: r.userId,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    state = const AsyncLoading();
    try {
      final r = await ref.read(authApiProvider).register(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            password: password,
            role: role,
          );
      await ref.read(tokenStoreProvider).setSession(
            access: r.accessToken,
            refresh: r.refreshToken,
            role: r.role.name,
            phoneNumber: r.phoneNumber,
            userId: r.userId,
          );
      state = AsyncData(AuthState(
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        role: r.role,
        phoneNumber: r.phoneNumber,
        userId: r.userId,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final s = state.value;
    final tok = ref.read(tokenStoreProvider);
    if (s?.refreshToken != null) {
      await ref.read(authApiProvider).logout(s!.refreshToken!);
    }
    await tok.clear();
    state = AsyncData(AuthState());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

// -- KYC Protection --------------------------------------------------
/// Returns true if KYC is verified, false otherwise
final isKycVerifiedProvider = FutureProvider.autoDispose((ref) async {
  try {
    final summary = await ref.watch(walletApiProvider).summary();
    return summary.isKycVerified;
  } catch (_) {
    return false;
  }
});

/// Get user's KYC status
final kycStatusProvider = FutureProvider.autoDispose((ref) async {
  try {
    final summary = await ref.watch(walletApiProvider).summary();
    return summary.kycStatus;
  } catch (_) {
    return 'None';
  }
});
