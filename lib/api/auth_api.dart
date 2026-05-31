import 'package:dio/dio.dart';

import '../models/api_models.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._c);
  final ApiClient _c;

  Future<LoginResponse> login(String email, String password) async {
    try {
      final r = await _c.dio.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
        options: Options(
          extra: {'skipAuth': true},
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return LoginResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<LoginResponse> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    try {
      final r = await _c.dio.post(
        '/api/v1/auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
          'role': role,
        },
        options: Options(
          extra: {'skipAuth': true},
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return LoginResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<LoginResponse> loginWithFingerprint({
    required String fingerprintId,
    required bool matched,
  }) async {
    try {
      final r = await _c.dio.post(
        '/api/v1/auth/login-fingerprint',
        data: {
          'fingerprintId': fingerprintId,
          'matched': matched,
        },
        options: Options(
          extra: {'skipAuth': true},
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return LoginResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _c.dio.post('/api/v1/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {
      // Best effort — local state is cleared regardless.
    }
  }
}
