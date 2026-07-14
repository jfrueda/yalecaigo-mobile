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
      data: {'username': normalizedUsername, 'password': password},
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
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String city,
    required bool termsAccepted,
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
        'phone_number': phoneNumber.trim(),
        'password': password,
        'role': normalizedRole,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'city': city.trim(),
        'terms_accepted': termsAccepted,
      },
    );

    await login(normalizedUsername, password);
  }

  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.passwordResetRequest,
      data: {'identifier': identifier.trim()},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<void> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    await PublicApiClient.dio.post<dynamic>(
      Endpoints.passwordResetConfirm,
      data: {
        'uid': uid.trim(),
        'token': token.trim(),
        'new_password': newPassword,
      },
    );
  }
}
