import 'package:dio/dio.dart';

import '../config/app_config.dart';

final Dio refreshDio = Dio(
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
