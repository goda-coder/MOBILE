import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../api/api_client.dart';
import '../services/biometric_auth_service.dart';
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
    await ref.read(tokenStoreProvider).clear();
    return AuthState();
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

class HasOnboarded extends Notifier<bool> {
  HasOnboarded(this._initialValue);
  final bool _initialValue;

  @override
  bool build() => _initialValue;

  void set(bool val) => state = val;
}

final hasOnboardedProvider = NotifierProvider<HasOnboarded, bool>(() => HasOnboarded(false));

// -- Biometrics -------------------------------------------------------
/// Temporary holder for credentials after registration, so the
/// enable-biometrics page can read them without routing complexity.
class PendingBiometricCredentials extends Notifier<Map<String, String>?> {
  @override
  Map<String, String>? build() => null;

  void set(Map<String, String>? creds) => state = creds;
}

final pendingBiometricCredentialsProvider =
    NotifierProvider<PendingBiometricCredentials, Map<String, String>?>(
        PendingBiometricCredentials.new);

final biometricServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthServiceImpl(
    localAuth: LocalAuthentication(),
    secureStorage: ref.read(secureStorageProvider),
  );
});

class BiometricState {
  BiometricState({
    this.isDeviceSupported = false,
    this.hasBiometricsEnrolled = false,
    this.isBiometricEnabled = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isDeviceSupported;
  final bool hasBiometricsEnrolled;
  final bool isBiometricEnabled;
  final bool isLoading;
  final String? errorMessage;

  BiometricState copyWith({
    bool? isDeviceSupported,
    bool? hasBiometricsEnrolled,
    bool? isBiometricEnabled,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BiometricState(
      isDeviceSupported: isDeviceSupported ?? this.isDeviceSupported,
      hasBiometricsEnrolled:
          hasBiometricsEnrolled ?? this.hasBiometricsEnrolled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class BiometricController extends Notifier<BiometricState> {
  @override
  BiometricState build() {
    _checkStatus();
    return BiometricState(isLoading: true);
  }

  Future<void> _checkStatus() async {
    try {
      final service = ref.read(biometricServiceProvider);
      final supported = await service.isDeviceSupported();
      final enrolled =
          supported ? await service.hasEnrolledBiometrics() : false;
      final enabled = await service.isBiometricEnabled();
      state = BiometricState(
        isDeviceSupported: supported,
        hasBiometricsEnrolled: enrolled,
        isBiometricEnabled: enabled ?? false,
      );
    } catch (e) {
      state = BiometricState(errorMessage: e.toString());
    }
  }

  Future<String?> enableBiometrics({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final service = ref.read(biometricServiceProvider);
      await service.setEnabled(true);
      if (phone.isNotEmpty && password.isNotEmpty) {
        await service.setCredentials(phone, password);
      }
      state = state.copyWith(
        isBiometricEnabled: true,
        isLoading: false,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return e.toString();
    }
  }

  Future<bool> authenticateAndSignIn() async {
    final service = ref.read(biometricServiceProvider);
    final authed = await service.authenticate();
    if (!authed) return false;

    final creds = await service.getCredentials();
    if (creds == null) return false;

    try {
      await ref.read(authControllerProvider.notifier).signIn(
            creds['phone']!,
            creds['password']!,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshStatus() async {
    await _checkStatus();
  }
}

final biometricControllerProvider =
    NotifierProvider<BiometricController, BiometricState>(
  BiometricController.new,
);

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
