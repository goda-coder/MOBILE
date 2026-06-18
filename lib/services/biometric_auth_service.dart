import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthService {
  // used for device check for biometrics
  Future<bool> isDeviceSupported();
  Future<bool> hasEnrolledBiometrics();

  // used to persist the data in secure storage
  Future<bool?> isBiometricEnabled();
  Future<void> setEnabled(bool isEnabled);

  // used to store/retrieve credentials for biometric auto-login
  Future<void> setCredentials(String phone, String password);
  Future<Map<String, String>?> getCredentials();
  Future<void> clearCredentials();

  // used to authenticate when conditions meet
  Future<bool> authenticate();
}

class BiometricAuthServiceImpl implements BiometricAuthService {
  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  BiometricAuthServiceImpl(
      {required LocalAuthentication localAuth,
      required FlutterSecureStorage secureStorage})
      : _localAuth = localAuth,
        _secureStorage = secureStorage;

  @override
  Future<void> setCredentials(String phone, String password) async {
    await _secureStorage.write(key: "biometric-phone", value: phone);
    await _secureStorage.write(key: "biometric-password", value: password);
  }

  @override
  Future<Map<String, String>?> getCredentials() async {
    final phone = await _secureStorage.read(key: "biometric-phone");
    final password = await _secureStorage.read(key: "biometric-password");
    if (phone == null || password == null) return null;
    return {"phone": phone, "password": password};
  }

  @override
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: "biometric-phone");
    await _secureStorage.delete(key: "biometric-password");
  }

  @override
  Future<bool> authenticate() async {
    final isSupported = await isDeviceSupported();
    if (!isSupported) {
      return false;
    }

    final enrolled = await hasEnrolledBiometrics();
    if (!enrolled) {
      return false;
    }

    return await _localAuth.authenticate(
        localizedReason: "Authenticate to access your account",
        biometricOnly: true);
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isDeviceSupported() async {
    try {
      if (await _localAuth.canCheckBiometrics) return true;
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool isEnabled) async {
    await _secureStorage.write(
        key: "biometric-enabled", value: isEnabled.toString());
  }

  @override
  Future<bool?> isBiometricEnabled() async {
    final isEnabled = await _secureStorage.read(key: "biometric-enabled");
    return isEnabled == null ? false : bool.tryParse(isEnabled);
  }
}
