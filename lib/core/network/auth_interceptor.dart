import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'endpoints.dart';
import 'refresh_dio.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  bool _refreshing = false;

  AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // ❌ NO interceptar auth
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }

    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        _refreshing ||
        err.requestOptions.path.startsWith('/auth/')) {
      return handler.next(err);
    }

    _refreshing = true;

    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh == null) throw Exception('No refresh');

      final res = await refreshDio.post(
        Endpoints.tokenRefresh,
        data: {'refresh': refresh},
      );

      final newAccess = res.data['access'] as String;
      await TokenStorage.saveTokens(
        access: newAccess,
        refresh: refresh,
      );

      _refreshing = false;

      final retry = err.requestOptions;
      retry.headers['Authorization'] = 'Bearer $newAccess';

      final response = await dio.fetch(retry);
      return handler.resolve(response);
    } catch (e) {
      _refreshing = false;
      await TokenStorage.clear();
      return handler.next(err);
    }
  }
}
