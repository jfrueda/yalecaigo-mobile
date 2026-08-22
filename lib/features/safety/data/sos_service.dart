import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'pending_sos_store.dart';

String formatSosCoordinate(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'La coordenada debe ser finita.');
  }
  return value.toStringAsFixed(6);
}

String newSosClientEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

bool isSosTransportFailure(DioException error) => error.response == null;

class SosService {
  Future<Map<String, dynamic>> create(PendingSosEvent event) async {
    final response = await ApiClient.dio.post<dynamic>(
      Endpoints.sos,
      data: event.toApiPayload(),
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> active(int serviceRequestId) async {
    final response = await ApiClient.dio.get<dynamic>(
      Endpoints.activeSos,
      queryParameters: {'service_request': serviceRequestId},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<Map<String, dynamic>> detail(int incidentId) async {
    final response = await ApiClient.dio.get<dynamic>(
      Endpoints.sosDetail(incidentId),
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }
}
