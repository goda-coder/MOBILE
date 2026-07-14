import 'package:dio/dio.dart';

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

/// In-memory auth-token cache. Data lives only for the current app session.
/// One instance is wired into both the Dio interceptor and the auth state.
class TokenStore {
  final _data = <String, String>{};

  Future<String?> getAccess() async => _data['access'];
  Future<String?> getRefresh() async => _data['refresh'];

  Future<void> setTokens(String access, String refresh) async {
    _data['access'] = access;
    _data['refresh'] = refresh;
  }

  Future<void> setSession({
    required String access,
    required String refresh,
    required String role,
    required String phoneNumber,
    required String userId,
    String fullName = '',
    bool hasPin = false,
    bool isKycVerified = false,
  }) async {
    _data['access'] = access;
    _data['refresh'] = refresh;
    _data['role'] = role;
    _data['phoneNumber'] = phoneNumber;
    _data['userId'] = userId;
    _data['fullName'] = fullName;
    _data['hasPin'] = hasPin.toString();
    _data['isKycVerified'] = isKycVerified.toString();
  }

  Future<bool> getHasPin() async => _data['hasPin'] == 'true';
  Future<bool> getKycVerified() async => _data['isKycVerified'] == 'true';

  Future<void> setHasPin(bool value) async {
    _data['hasPin'] = value.toString();
  }

  Future<void> setKycVerified(bool value) async {
    _data['isKycVerified'] = value.toString();
  }

  Future<Map<String, String?>> getSession() async => {
        'access': _data['access'],
        'refresh': _data['refresh'],
        'role': _data['role'],
        'phoneNumber': _data['phoneNumber'],
        'userId': _data['userId'],
        'fullName': _data['fullName'],
        'hasPin': _data['hasPin'],
        'isKycVerified': _data['isKycVerified'],
      };

  Future<void> clear() async {
    _data.clear();
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
      final requestedUrl =
          '${e.requestOptions.baseUrl}${e.requestOptions.path}';
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
        if (refresh == null) {
          _refreshing = false;
          return handler.next(err);
        }

        final r = await dio.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(extra: {'skipAuth': true}),
        );
        final newAccess = r.data['accessToken'] as String;
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
