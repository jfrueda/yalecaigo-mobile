import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class MeService {
  Future<Map<String, dynamic>> getMe() async {
    Response<dynamic> response;
    try {
      response = await ApiClient.dio.get(Endpoints.me);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      response = await ApiClient.dio.get(Endpoints.authMe);
    }

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('La respuesta del perfil no es un objeto.');
    }
    return Map<String, dynamic>.from(data);
  }
}
