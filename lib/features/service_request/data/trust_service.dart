import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class TrustService {
  Future<Map<String, dynamic>> getMyRating(int requestId) async {
    final response = await ApiClient.dio.get(
      Endpoints.ratingRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reportBehavior({
    required int requestId,
    required String category,
    String description = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.behaviorReport(requestId),
      data: {'category': category, 'description': description.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> blockUser({
    required int userId,
    required int sourceServiceId,
    String reason = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.blockUser(userId),
      data: {'source_service': sourceServiceId, 'reason': reason.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> unblockUser(int userId) async {
    final response = await ApiClient.dio.delete(Endpoints.blockUser(userId));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers() async {
    final response = await ApiClient.dio.get(Endpoints.blockedUsers);
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> providerReputation(int providerId) async {
    final response = await ApiClient.dio.get(
      Endpoints.providerReputation(providerId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
