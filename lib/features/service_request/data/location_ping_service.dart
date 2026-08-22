import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

/// Formats a GPS coordinate with the precision accepted by the Django API.
///
/// The backend stores latitude/longitude as DecimalField(decimal_places: 6).
/// Six decimals already provide sub-meter coordinate resolution, while a real
/// phone GPS normally has an accuracy of several meters.
String formatCoordinateForApi(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'La coordenada debe ser finita.');
  }
  return value.toStringAsFixed(6);
}

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
        // Send fixed-point strings so DRF DecimalField never receives more
        // than six decimal places from Geolocator's high-precision doubles.
        'latitude': formatCoordinateForApi(locationLat),
        'longitude': formatCoordinateForApi(locationLng),
        'accuracy': accuracy,
        'source': source,
      },
    );
  }
}
