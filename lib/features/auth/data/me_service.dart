import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class MeService {
  Future<Map<String, dynamic>> getMe() async {
    final Response res = await ApiClient.dio.get('/security/me/');
    return Map<String, dynamic>.from(res.data);
  }
}
