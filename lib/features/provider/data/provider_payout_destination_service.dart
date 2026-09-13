import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class ProviderPayoutDestinationService {
  Future<List<Map<String, dynamic>>> listDestinations() async {
    final response = await ApiClient.dio.get(
      Endpoints.payoutDestinations,
      queryParameters: {'_refresh': DateTime.now().microsecondsSinceEpoch},
      options: Options(
        headers: const {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ),
    );
    final raw = response.data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createDestination(
    Map<String, dynamic> data,
  ) async {
    final response = await ApiClient.dio.post(
      Endpoints.payoutDestinations,
      data: data,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> setPrimary(int destinationId) async {
    final response = await ApiClient.dio.post(
      Endpoints.payoutDestinationPrimary(destinationId),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deactivate(int destinationId) async {
    await ApiClient.dio.delete(Endpoints.payoutDestination(destinationId));
  }
}
