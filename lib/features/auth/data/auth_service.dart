import 'package:dio/dio.dart';

import '../../../core/branding/app_branding.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/public_api_client.dart';
import '../../../core/network/token_storage.dart';

class AuthSessionResult {
  const AuthSessionResult({required this.data});
  final Map<String, dynamic> data;
  String get result => data['result']?.toString() ?? 'authenticated';
  String? get registrationToken => data['registration_token']?.toString();
  Map<String, dynamic> get profile => Map<String, dynamic>.from(
    data['profile'] is Map ? data['profile'] as Map : {},
  );
}

class RegistrationResult {
  const RegistrationResult({required this.data});
  final Map<String, dynamic> data;
  String? get challengeId {
    final verification = data['email_verification'];
    if (verification is! Map) return null;
    final challenge = verification['challenge'];
    if (challenge is! Map) return null;
    return challenge['challenge_id']?.toString();
  }
}

class AuthService {
  Future<Map<String, dynamic>> _deviceMetadata() async {
    return {
      'device_id': await TokenStorage.getOrCreateDeviceId(),
      'device_name': 'Aplicación ${AppBranding.appName}',
      'platform': 'ANDROID',
      'app_version': AppConfig.appVersion,
    };
  }

  Future<void> _storeSession(Map<String, dynamic> data) async {
    final access = data['access']?.toString();
    final refresh = data['refresh']?.toString();
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw const FormatException(
        'No pudimos iniciar la sesión. Intenta nuevamente.',
      );
    }
    await TokenStorage.saveTokens(access: access, refresh: refresh);
  }

  Future<AuthSessionResult> login(String identifier, String password) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty || password.isEmpty) {
      throw const FormatException(
        'Correo, teléfono o usuario y contraseña son obligatorios.',
      );
    }
    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.tokenObtain,
      data: {
        'identifier': normalized,
        'password': password,
        ...await _deviceMetadata(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    await _storeSession(data);
    return AuthSessionResult(data: data);
  }

  Future<RegistrationResult> register({
    required String email,
    required String phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String birthDate,
    required String gender,
    required String countryCode,
    required int residencePlaceId,
    required List<int> legalDocumentIds,
  }) async {
    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.register,
      data: {
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': birthDate,
        'gender': gender,
        'country_code': countryCode.trim().toUpperCase(),
        'residence_place_id': residencePlaceId,
        'legal_document_ids': legalDocumentIds,
        'accept_legal': true,
        ...await _deviceMetadata(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    await _storeSession(data);
    return RegistrationResult(data: data);
  }

  Future<List<Map<String, dynamic>>> getRegistrationCountries() async {
    final response = await PublicApiClient.dio.get<Map<String, dynamic>>(
      Endpoints.geographyCountries,
    );
    final results = response.data?['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getRegistrationPlaces({
    required String countryCode,
    required String level,
    int? parentId,
  }) async {
    final response = await PublicApiClient.dio.get<Map<String, dynamic>>(
      Endpoints.geographyPlaces,
      queryParameters: {
        'country': countryCode,
        'level': level,
        if (parentId != null) 'parent': parentId,
      },
    );
    final results = response.data?['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<AuthSessionResult> socialLogin({
    required String provider,
    required String token,
  }) async {
    final endpoint = provider == 'google'
        ? Endpoints.socialGoogle
        : Endpoints.socialFacebook;
    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      endpoint,
      data: {'token': token, ...await _deviceMetadata()},
    );
    final data = response.data ?? <String, dynamic>{};
    if (data['result'] == 'authenticated') await _storeSession(data);
    return AuthSessionResult(data: data);
  }

  Future<void> linkSocialIdentity({
    required String provider,
    required String token,
  }) async {
    await ApiClient.dio.post<dynamic>(
      Endpoints.socialLink,
      data: {'provider': provider.toUpperCase(), 'token': token},
    );
  }

  Future<AuthSessionResult> completeSocialRegistration({
    required String registrationToken,
    required String email,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String birthDate,
    required String gender,
    required String countryCode,
    required int residencePlaceId,
    required List<int> legalDocumentIds,
  }) async {
    final response = await PublicApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.socialCompleteRegistration,
      data: {
        'registration_token': registrationToken,
        'role': 'client',
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': birthDate,
        'gender': gender,
        'country_code': countryCode,
        'residence_place_id': residencePlaceId,
        'legal_document_ids': legalDocumentIds,
        'accept_legal': true,
        ...await _deviceMetadata(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    await _storeSession(data);
    return AuthSessionResult(data: data);
  }

  Future<String> requestEmailOtp() async {
    final response = await ApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.otpRequest,
      data: const {'purpose': 'VERIFY_EMAIL'},
    );
    final challenge = response.data?['challenge'];
    if (challenge is Map && challenge['challenge_id'] != null) {
      return challenge['challenge_id'].toString();
    }
    throw const FormatException('No se recibió el identificador del código.');
  }

  Future<void> verifyEmailOtp({
    required String challengeId,
    required String code,
  }) async {
    await ApiClient.dio.post<dynamic>(
      Endpoints.otpVerify,
      data: {'challenge_id': challengeId, 'code': code.trim()},
    );
  }

  Future<List<Map<String, dynamic>>> getLegalDocuments({
    String countryCode = 'CO',
  }) async {
    final response = await PublicApiClient.dio.get<Map<String, dynamic>>(
      Endpoints.legalDocuments,
      queryParameters: {'country': countryCode, 'language': 'es'},
    );
    final results = response.data?['results'];
    if (results is! List) return [];
    return results
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> acceptLegalDocuments(List<int> ids) async {
    await ApiClient.dio.post<dynamic>(
      Endpoints.consents,
      data: {'document_ids': ids, 'platform': 'ANDROID'},
    );
  }

  Future<Map<String, dynamic>> getOnboardingStatus() async {
    final response = await ApiClient.dio.get<Map<String, dynamic>>(
      Endpoints.onboardingStatus,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> requestPasswordReset(String identifier) async {
    await PublicApiClient.dio.post<dynamic>(
      Endpoints.passwordResetRequest,
      data: {'identifier': identifier.trim()},
    );
  }

  Future<void> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    await PublicApiClient.dio.post<dynamic>(
      Endpoints.passwordResetConfirm,
      data: {'uid': uid, 'token': token, 'new_password': newPassword},
    );
  }

  Future<void> logout() async {
    final refresh = await TokenStorage.getRefreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await ApiClient.dio.post<dynamic>(
          Endpoints.logout,
          data: {'refresh': refresh},
        );
      }
    } on DioException {
      // La sesión local se elimina incluso si el token ya expiró.
    } finally {
      await TokenStorage.clearSession();
    }
  }
}
