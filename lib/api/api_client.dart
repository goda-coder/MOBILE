import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when an HTTP call fails with a structured error body.
class ApiError implements Exception {
  ApiError(this.status, this.code, this.message, [this.details]);
  final int status;
  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'ApiError($status, $code): $message';
}

/// Keys used in flutter_secure_storage. Centralised so we can rotate later.
abstract final class _Keys {
  static const access  = 'wallet.accessToken';
  static const refresh = 'wallet.refreshToken';
  static const role    = 'wallet.role';
  static const phoneNumber = 'wallet.phoneNumber';
  static const userId  = 'wallet.userId';
}

/// Thin auth-token cache backed by the system Keychain / Android Keystore.
/// One instance is wired into both the Dio interceptor and the auth state.
class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> getAccess()  => _storage.read(key: _Keys.access);
  Future<String?> getRefresh() => _storage.read(key: _Keys.refresh);

  Future<void> setTokens(String access, String refresh) async {
    await _storage.write(key: _Keys.access,  value: access);
    await _storage.write(key: _Keys.refresh, value: refresh);
  }

  Future<void> setSession({
    required String access,
    required String refresh,
    required String role,
    required String phoneNumber,
    required String userId,
  }) async {
    await _storage.write(key: _Keys.access,  value: access);
    await _storage.write(key: _Keys.refresh, value: refresh);
    await _storage.write(key: _Keys.role,    value: role);
    await _storage.write(key: _Keys.phoneNumber,   value: phoneNumber);
    await _storage.write(key: _Keys.userId,  value: userId);
  }

  Future<Map<String, String?>> getSession() async => {
    'access':  await _storage.read(key: _Keys.access),
    'refresh': await _storage.read(key: _Keys.refresh),
    'role':    await _storage.read(key: _Keys.role),
    'phoneNumber':   await _storage.read(key: _Keys.phoneNumber),
    'userId':  await _storage.read(key: _Keys.userId),
  };

  Future<void> clear() async {
    await _storage.delete(key: _Keys.access);
    await _storage.delete(key: _Keys.refresh);
    await _storage.delete(key: _Keys.role);
    await _storage.delete(key: _Keys.phoneNumber);
    await _storage.delete(key: _Keys.userId);
  }
}

/// Configured Dio instance. Use [ApiClient.dio] for plain calls; the
/// interceptors inject the bearer token and rotate refresh tokens on 401.
class ApiClient {
  ApiClient({required String baseUrl, required this.tokens})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'application/json'},
        )) {
    dio.interceptors.add(_AuthInterceptor(tokens, dio));
  }

  final Dio dio;
  final TokenStore tokens;

  /// Convert a [DioException] into our [ApiError] shape.
  static ApiError toApiError(DioException e) {
    final res = e.response;
    if (res == null) {
      final requestedUrl = '${e.requestOptions.baseUrl}${e.requestOptions.path}';
      return ApiError(
        0,
        'NETWORK_ERROR',
        'Network unavailable while connecting to $requestedUrl. '
        'Confirm the backend is running and accessible from the browser.',
        e.message,
      );
    }
    final data = res.data;
    if (data is Map) {
      return ApiError(
        res.statusCode ?? 0,
        (data['code'] ?? 'HTTP_${res.statusCode}').toString(),
        (data['message'] ?? res.statusMessage ?? 'Request failed').toString(),
        data,
      );
    }
    return ApiError(
      res.statusCode ?? 0,
      'HTTP_${res.statusCode}',
      res.statusMessage ?? 'Request failed',
      data,
    );
  }
}

/// Injects the bearer token, and on 401 tries one refresh round-trip before
/// giving up and surfacing the failure.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.tokens, this.dio);
  final TokenStore tokens;
  final Dio dio;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final tok = await tokens.getAccess();
      if (tok != null) options.headers['Authorization'] = 'Bearer $tok';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 from non-auth endpoints, and only attempt one refresh.
    final isAuthEndpoint = err.requestOptions.path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra['didRefresh'] == true;

    if (err.response?.statusCode == 401 &&
        !isAuthEndpoint &&
        !alreadyRetried &&
        !_refreshing) {
      _refreshing = true;
      try {
        final refresh = await tokens.getRefresh();
        if (refresh == null) { _refreshing = false; return handler.next(err); }

        final r = await dio.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(extra: {'skipAuth': true}),
        );
        final newAccess  = r.data['accessToken']  as String;
        final newRefresh = r.data['refreshToken'] as String;
        await tokens.setTokens(newAccess, newRefresh);

        // Retry the original request with the new token.
        final req = err.requestOptions;
        req.headers['Authorization'] = 'Bearer $newAccess';
        req.extra['didRefresh'] = true;
        final retried = await dio.fetch(req);
        _refreshing = false;
        return handler.resolve(retried);
      } catch (_) {
        // Refresh failed — wipe state. The auth provider will route to /login
        // on the next build because access will be null.
        await tokens.clear();
        _refreshing = false;
      }
    }
    handler.next(err);
  }
}
