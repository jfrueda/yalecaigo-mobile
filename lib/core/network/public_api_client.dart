import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class PublicApiClient {
  PublicApiClient._();

  static final Dio dio = _buildDio();

  static Dio _buildDio() {
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

    if (AppConfig.enableNetworkLogs) {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[API PUBLIC] --> ${options.method} ${options.uri}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[API PUBLIC] <-- ${response.statusCode} '
              '${response.requestOptions.method} '
              '${response.requestOptions.uri}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '[API PUBLIC] xx ${error.response?.statusCode ?? '-'} '
              '${error.requestOptions.method} '
              '${error.requestOptions.uri} '
              'type=${error.type} message=${error.message}',
            );
            handler.next(error);
          },
        ),
      );
    }

    return client;
  }
}
