import 'package:dio/dio.dart';

import 'endpoints.dart';
import 'refresh_dio.dart';
import 'token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.dio);

  final Dio dio;
  Future<String?>? _refreshFuture;

  bool _isPublicAuthPath(String path) {
    return path == Endpoints.tokenObtain ||
        path == Endpoints.tokenRefresh ||
        path == Endpoints.register;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthPath(options.path)) {
      handler.next(options);
      return;
    }

    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        !_isPublicAuthPath(request.path) &&
        request.extra['_jwtRetried'] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    try {
      final future = _refreshFuture ??= _refreshAccessToken();
      final newAccess = await future;
      _refreshFuture = null;

      if (newAccess == null || newAccess.isEmpty) {
        await TokenStorage.clearSession();
        handler.next(err);
        return;
      }

      request.extra['_jwtRetried'] = true;
      request.headers['Authorization'] = 'Bearer $newAccess';
      final response = await dio.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      _refreshFuture = null;
      await TokenStorage.clearSession();
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessToken() async {
    final currentRefresh = await TokenStorage.getRefreshToken();
    if (currentRefresh == null || currentRefresh.isEmpty) {
      return null;
    }

    final response = await refreshDio.post<Map<String, dynamic>>(
      Endpoints.tokenRefresh,
      data: {'refresh': currentRefresh},
    );

    final payload = response.data;
    final access = payload?['access']?.toString();
    if (access == null || access.isEmpty) {
      return null;
    }

    final rotatedRefresh = payload?['refresh']?.toString();
    await TokenStorage.saveTokens(
      access: access,
      refresh: (rotatedRefresh == null || rotatedRefresh.isEmpty)
          ? currentRefresh
          : rotatedRefresh,
    );

    return access;
  }
}
