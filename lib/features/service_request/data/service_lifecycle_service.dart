import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class ServiceLifecycleService {
  Future<Map<String, dynamic>> arrive(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.arriveRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> start(int requestId, String code) async {
    final response = await ApiClient.dio.post(
      Endpoints.startRequest(requestId),
      data: {'code': code.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> finish(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.finishRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> notifyLateArrival({
    required int requestId,
    required int etaMinutes,
    String message = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.lateRequest(requestId),
      data: {'eta_minutes': etaMinutes, 'message': message.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> cancel({
    required int requestId,
    required String reasonCode,
    String reason = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.cancelRequest(requestId),
      data: {'reason_code': reasonCode, 'reason': reason.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> rate({
    required int requestId,
    required int score,
    String comment = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.rateRequest(requestId),
      data: {'score': score, 'comment': comment.trim()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> reportRisk({
    required int requestId,
    required String reason,
    double? latitude,
    double? longitude,
  }) async {
    await ApiClient.dio.post(
      Endpoints.panicEvents,
      data: {
        'service_request': requestId,
        'reason': reason.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
  }
}
