import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_storage.dart';

class AuthService {
  /// LOGIN NORMAL
  Future<void> login(String username, String password) async {
    final res = await ApiClient.dio.post(
      '/auth/token/',
      data: {
        'username': username,
        'password': password,
      },
    );

    final access = res.data['access'];
    final refresh = res.data['refresh'];

    await TokenStorage.saveTokens(
      access: access,
      refresh: refresh,
    );
  }

  /// REGISTRO + AUTO LOGIN (MVP)
  Future<void> registerAndLogin({
    required String username,
    required String password,
  }) async {
    // 1️⃣ Registrar
    await ApiClient.dio.post(
      '/auth/register/',
      data: {
        'username': username,
        'password': password,
      },
    );

    // 2️⃣ Login automático
    await login(username, password);
  }
}

