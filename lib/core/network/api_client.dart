import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient._();

  static final Dio dio = _buildClient();

  static Dio _buildClient() {
    final client = Dio(
      BaseOptions(
        baseUrl: AppConfig.normalizedBaseUrl,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
      ),
    );

    client.interceptors.add(AuthInterceptor(client));

    if (kDebugMode && AppConfig.enableNetworkLogs) {
      client.interceptors.add(_SafeNetworkLogInterceptor());
    }

    return client;
  }
}

/// Registra únicamente método, URL y estado. No imprime cuerpos, contraseñas,
/// encabezados de autorización ni tokens.
class _SafeNetworkLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] --> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[API] <-- ${response.statusCode} '
      '${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[API] xx ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.method} ${err.requestOptions.uri}: '
      '${err.type.name}',
    );
    handler.next(err);
  }
}
