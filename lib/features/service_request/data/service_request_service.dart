import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class ServiceRequestService {
  Future<Response<dynamic>> createRequest({
    required int categoryId,
    required String locationText,
    required double locationLat,
    required double locationLng,
    required DateTime requestedStartTime,
    required int requestedDurationMinutes,
    String? notes,
    String? preferredGender,
    int? preferredAgeMin,
    int? preferredAgeMax,
  }) {
    final payload = <String, dynamic>{
      'category': categoryId,
      'location_text': locationText,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'requested_start_time': requestedStartTime.toUtc().toIso8601String(),
      'requested_duration_minutes': requestedDurationMinutes,
    };

    final normalizedNotes = notes?.trim();
    if (normalizedNotes != null && normalizedNotes.isNotEmpty) {
      payload['notes'] = normalizedNotes;
    }
    if (preferredGender != null && preferredGender.isNotEmpty) {
      payload['preferred_gender'] = preferredGender;
    }
    if (preferredAgeMin != null) {
      payload['preferred_age_min'] = preferredAgeMin;
    }
    if (preferredAgeMax != null) {
      payload['preferred_age_max'] = preferredAgeMax;
    }

    return ApiClient.dio.post(Endpoints.serviceRequests, data: payload);
  }
}
