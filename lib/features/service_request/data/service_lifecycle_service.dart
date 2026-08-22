import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class ServiceLifecycleService {
  Future<Map<String, dynamic>> confirmParticipation(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.confirmRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> markEnRoute(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.enRouteRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

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

  /// Phase 4A collaborative close. Both participants must confirm.
  Future<Map<String, dynamic>> confirmCompletion(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.completionRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Legacy close endpoint retained for compatibility with older flows/tests.
  Future<Map<String, dynamic>> finish(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.finishRequest(requestId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reportNoShow(int requestId) async {
    final response = await ApiClient.dio.post(
      Endpoints.noShowRequest(requestId),
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

  Future<Map<String, dynamic>> proposeReschedule({
    required int requestId,
    required DateTime proposedStartTime,
    String reason = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.rescheduleRequest(requestId),
      data: {
        'proposed_start_time': proposedStartTime.toUtc().toIso8601String(),
        'reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> respondReschedule({
    required int requestId,
    required bool accept,
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.respondRescheduleRequest(requestId),
      data: {'action': accept ? 'accept' : 'reject'},
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
    String privateComment = '',
    String publicComment = '',
  }) async {
    final response = await ApiClient.dio.post(
      Endpoints.rateRequest(requestId),
      data: {
        'score': score,
        'private_comment': privateComment.trim(),
        'public_comment': publicComment.trim(),
      },
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
