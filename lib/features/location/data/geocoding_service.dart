import 'package:dio/dio.dart';

class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        // Nominatim recomienda identificar el user-agent
        'User-Agent': 'yalecaigo-mvp/1.0 (contact: soporte@opentic.co)',
      },
    ),
  );

  /// Retorna un nombre amigable (display_name) usando reverse geocode.
  Future<String?> reverse({
    required double lat,
    required double lng,
  }) async {
    final res = await _dio.get(
      '/reverse',
      queryParameters: {
        'format': 'jsonv2',
        'lat': lat,
        'lon': lng,
        'zoom': 18,
        'addressdetails': 1,
      },
    );

    final data = res.data;
    if (data is Map && data['display_name'] != null) {
      return data['display_name'].toString();
    }
    return null;
  }
}
