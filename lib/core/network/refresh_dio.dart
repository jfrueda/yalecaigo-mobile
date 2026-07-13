import 'package:dio/dio.dart';
import '../config/app_config.dart';

final Dio refreshDio = Dio(
  BaseOptions(
    baseUrl: AppConfig.baseUrl,
    headers: {'Content-Type': 'application/json'},
  ),
);
