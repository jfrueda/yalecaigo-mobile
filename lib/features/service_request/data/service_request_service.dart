import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ServiceRequestService {
  Future<Response> createRequest({
    required int categoryId,
    required String locationText,
    required double locationLat,
    required double locationLng,
    required DateTime requestedStartTime,
    required int requestedDurationMinutes,

    String? notes,

    // ⭐ NUEVO
    String? preferredGender,
    int? preferredAgeMin,
    int? preferredAgeMax,
  }) async {
    final payload = <String, dynamic>{
      'category': categoryId,
      'location_text': locationText,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'requested_start_time': requestedStartTime.toUtc().toIso8601String(),
      'requested_duration_minutes': requestedDurationMinutes,
    };

    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

    // ⭐ NUEVO: preferencias (solo si vienen)
    if (preferredGender != null) payload['preferred_gender'] = preferredGender;
    if (preferredAgeMin != null) payload['preferred_age_min'] = preferredAgeMin;
    if (preferredAgeMax != null) payload['preferred_age_max'] = preferredAgeMax;

    return await ApiClient.dio.post('/services/requests/', data: payload);
  }
}


