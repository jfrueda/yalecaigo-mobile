import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class AccountService {
  Future<Map<String, dynamic>> getModes() async {
    final response = await ApiClient.dio.get<dynamic>(Endpoints.modes);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> setActiveMode(String mode) async {
    final response = await ApiClient.dio.patch<dynamic>(
      Endpoints.modes,
      data: {'active_mode': mode.toUpperCase()},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getSocialAccounts() async {
    final response = await ApiClient.dio.get<dynamic>(Endpoints.socialAccounts);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<void> unlinkSocialAccount(String provider) async {
    await ApiClient.dio.delete<dynamic>(Endpoints.socialUnlink(provider));
  }

  Future<List<Map<String, dynamic>>> listSessions() async {
    final response = await ApiClient.dio.get(Endpoints.sessions);
    final data = response.data;
    final results = data is Map ? data['results'] : null;
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await ApiClient.dio.delete<dynamic>(Endpoints.session(sessionId));
  }

  Future<void> logoutOthers() async {
    await ApiClient.dio.post<dynamic>(Endpoints.logoutOthers);
  }

  Future<List<Map<String, dynamic>>> listEmergencyContacts() async {
    final response = await ApiClient.dio.get(Endpoints.emergencyContacts);
    final data = response.data;
    final results = data is Map ? data['results'] : null;
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createEmergencyContact(
    Map<String, dynamic> values,
  ) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.emergencyContacts,
      data: values,
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> updateEmergencyContact(
    int id,
    Map<String, dynamic> values,
  ) async {
    final response = await ApiClient.dio.patch<dynamic>(
      Endpoints.emergencyContact(id),
      data: values,
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<void> deleteEmergencyContact(int id) async {
    await ApiClient.dio.delete<dynamic>(Endpoints.emergencyContact(id));
  }

  Future<Map<String, dynamic>> getProviderCapabilities() async {
    final response = await ApiClient.dio.get(Endpoints.providerCapabilities);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> updateProviderCapabilities({
    required List<int> categoryIds,
    required List<int> subcategoryIds,
  }) async {
    final response = await ApiClient.dio.put<dynamic>(
      Endpoints.providerCapabilities,
      data: {'category_ids': categoryIds, 'subcategory_ids': subcategoryIds},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getAvailability() async {
    final response = await ApiClient.dio.get(Endpoints.availability);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> updateAvailability(bool isAvailable) async {
    final response = await ApiClient.dio.patch<dynamic>(
      Endpoints.availability,
      data: {'is_available': isAvailable},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getAccountDeletionStatus() async {
    final response = await ApiClient.dio.get(Endpoints.accountDeletionStatus);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> requestAccountDeletion({
    required String password,
    String reason = '',
  }) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.accountDeletionRequest,
      data: {'password': password, 'reason': reason.trim()},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> confirmAccountDeletion({
    required String requestId,
    required String code,
  }) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.accountDeletionConfirm,
      data: {'request_id': requestId, 'code': code.trim()},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> cancelAccountDeletion({
    required String requestId,
    String cancellationToken = '',
  }) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.accountDeletionCancel,
      data: {
        'request_id': requestId,
        'cancellation_token': cancellationToken.trim(),
      },
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getSecurityPhone() async {
    final response = await ApiClient.dio.get(Endpoints.securityPhone);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> updateSecurityPhone(String phoneNumber) async {
    final response = await ApiClient.dio.patch<dynamic>(
      Endpoints.securityPhone,
      data: {'phone_number': phoneNumber.trim()},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await ApiClient.dio.get(Endpoints.profile);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> getLocationOptions({
    String country = 'Colombia',
    String query = '',
  }) async {
    final response = await ApiClient.dio.get<dynamic>(
      Endpoints.locationOptions,
      queryParameters: {
        'country': country,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> updateProfile(dynamic data) async {
    final response = await ApiClient.dio.patch<dynamic>(
      Endpoints.profile,
      data: data,
    );
    final value = response.data;
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<Map<String, dynamic>> submitProviderProfile() async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.providerProfileSubmitReview,
      data: const {'confirm': true},
    );
    final value = response.data;
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<Map<String, dynamic>> getIdentityVerification() async {
    final response = await ApiClient.dio.get(Endpoints.identityVerification);
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> submitIdentity(
    dynamic data, {
    required bool resubmission,
  }) async {
    final endpoint = resubmission
        ? Endpoints.identityVerificationResubmit
        : Endpoints.identityVerification;
    final response = await ApiClient.dio.post<dynamic>(endpoint, data: data);
    final value = response.data;
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }
}
