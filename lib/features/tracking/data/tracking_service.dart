import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class TrackingService {
  Future<Map<String, dynamic>> snapshot(int requestId) async {
    final response = await ApiClient.dio.get(
      Endpoints.trackingRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createShareLink({
    required int requestId,
    int durationMinutes = 360,
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.shareRequest(requestId),
      data: {'duration_minutes': durationMinutes},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<int> revokeShareLinks(int requestId) async {
    final response = await ApiClient.dio.delete(
      Endpoints.shareRequest(requestId),
    );
    final data = response.data;
    if (data is Map) {
      final value = data['revoked'];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  Future<Map<String, dynamic>?> currentSafetyTimer(int requestId) async {
    final response = await ApiClient.dio.get(
      Endpoints.safetyTimerRequest(requestId),
    );
    final data = response.data;
    if (data is! Map) return null;
    final timer = data['timer'];
    if (timer is! Map) return null;
    return Map<String, dynamic>.from(timer);
  }

  Future<Map<String, dynamic>> startSafetyTimer({
    required int requestId,
    required int durationMinutes,
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.safetyTimerRequest(requestId),
      data: {'duration_minutes': durationMinutes},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>?> cancelSafetyTimer(int requestId) async {
    final response = await ApiClient.dio.delete(
      Endpoints.safetyTimerRequest(requestId),
    );
    final data = response.data;
    if (data is! Map) return null;
    if (data.containsKey('detail')) return null;
    return Map<String, dynamic>.from(data);
  }
}
