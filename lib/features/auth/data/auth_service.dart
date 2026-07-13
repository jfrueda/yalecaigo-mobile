import '../../../core/network/endpoints.dart';
import '../../../core/network/public_api_client.dart';
import '../../../core/network/token_storage.dart';

class AuthService {
  Future<void> login(String username, String password) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const FormatException('Usuario y contraseña son obligatorios.');
    }

    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.tokenObtain,
      data: {
        'username': normalizedUsername,
        'password': password,
      },
    );

    final access = response.data?['access']?.toString();
    final refresh = response.data?['refresh']?.toString();
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw const FormatException(
        'El backend no devolvió los tokens access y refresh esperados.',
      );
    }

    await TokenStorage.saveTokens(access: access, refresh: refresh);
  }

  Future<void> registerAndLogin({
    required String username,
    required String password,
    required String role,
    String email = '',
  }) async {
    final normalizedUsername = username.trim();
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const FormatException('Usuario y contraseña son obligatorios.');
    }
    if (!const {'client', 'provider'}.contains(normalizedRole)) {
      throw const FormatException('El rol de registro no es válido.');
    }

    await PublicApiClient.dio.post<dynamic>(
      Endpoints.register,
      data: {
        'username': normalizedUsername,
        'email': email.trim(),
        'password': password,
        'role': normalizedRole,
      },
    );

    await login(normalizedUsername, password);
  }
}
