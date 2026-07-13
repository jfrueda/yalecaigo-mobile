import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class LocationPingService {
  Future<Response<dynamic>> createPing({
    required int serviceRequestId,
    required double locationLat,
    required double locationLng,
    String source = 'simulated',
    double accuracy = 10,
  }) {
    return ApiClient.dio.post(
      Endpoints.locationPings,
      data: {
        'service_request': serviceRequestId,
        'latitude': locationLat,
        'longitude': locationLng,
        'accuracy': accuracy,
        'source': source,
      },
    );
  }
}
