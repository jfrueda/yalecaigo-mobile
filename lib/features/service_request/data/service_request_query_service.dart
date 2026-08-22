import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class ServiceRequestQueryService {
  Future<List<Map<String, dynamic>>> listMyRequests() async {
    final response = await ApiClient.dio.get(Endpoints.serviceRequests);
    return _asList(response.data);
  }

  Future<List<Map<String, dynamic>>> listProviderHistory() async {
    final response = await ApiClient.dio.get(Endpoints.providerHistory);
    return _asList(response.data);
  }

  Future<Map<String, dynamic>?> getActiveRequest() async {
    try {
      final response = await ApiClient.dio.get(Endpoints.activeRequest);
      return _firstMap(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) {
        // El backend actual usa 404 para indicar que no existe una actividad
        // activa. No se debe caer a /requests/, porque ese endpoint es solo
        // para solicitantes y provocaría 403 en cuentas PROVIDER.
        return null;
      }
      if (status != 405) {
        rethrow;
      }

      // Compatibilidad exclusiva con backends antiguos que no implementaban
      // /active/ y respondían 405.
      final requests = await listMyRequests();
      for (final request in requests) {
        final requestStatus = request['status']?.toString().toLowerCase();
        if (const {
          'pending',
          'searching',
          'matched',
          'started',
        }.contains(requestStatus)) {
          return request;
        }
      }
      return null;
    }
  }

  Future<void> dismissRequest(
    int id, {
    String reason = 'No me interesa',
  }) async {
    await ApiClient.dio.post<dynamic>(
      Endpoints.dismissRequest(id),
      data: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>?> getRequestById(int id) async {
    try {
      final response = await ApiClient.dio.get(Endpoints.serviceRequest(id));
      return _firstMap(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    dynamic raw = data;
    if (raw is Map && raw['results'] is List) {
      raw = raw['results'];
    }

    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _firstMap(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      if (data['results'] is List) {
        final results = _asList(data);
        return results.isEmpty ? null : results.first;
      }
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      final results = _asList(data);
      return results.isEmpty ? null : results.first;
    }

    return null;
  }
}
