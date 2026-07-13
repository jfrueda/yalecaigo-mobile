import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class LocationPingService {
  Future<Response<dynamic>> createPing({
    required int serviceRequestId,
    required double locationLat,
    required double locationLng,
    required DateTime recordedAt,
  }) {
    return ApiClient.dio.post(
      '/services/location-pings/',
      data: {
        "service_request": serviceRequestId,
        "latitude": locationLat,     // ✅ backend espera latitude
        "longitude": locationLng,    // ✅ backend espera longitude
        "accuracy": 10.0,            // ✅ requerido por serializer
        "recorded_at": recordedAt.toUtc().toIso8601String(),
      },
    );
  }
}

