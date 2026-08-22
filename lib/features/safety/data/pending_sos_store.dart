import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PendingSosEvent {
  const PendingSosEvent({
    required this.serviceRequestId,
    required this.clientEventId,
    required this.reason,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.locationCapturedAt,
  });

  final int serviceRequestId;
  final String clientEventId;
  final String reason;
  final String createdAt;
  final String? latitude;
  final String? longitude;
  final double? locationAccuracy;
  final String? locationCapturedAt;

  Map<String, dynamic> toJson() => {
    'service_request': serviceRequestId,
    'client_event_id': clientEventId,
    'reason': reason,
    'created_at': createdAt,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
    if (locationCapturedAt != null) 'location_captured_at': locationCapturedAt,
  };

  Map<String, dynamic> toApiPayload() => {
    'service_request': serviceRequestId,
    'client_event_id': clientEventId,
    if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
    if (locationCapturedAt != null) 'location_captured_at': locationCapturedAt,
  };

  static PendingSosEvent? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final serviceRequestId = int.tryParse(
      map['service_request']?.toString() ?? '',
    );
    final clientEventId = map['client_event_id']?.toString() ?? '';
    if (serviceRequestId == null || clientEventId.isEmpty) return null;
    return PendingSosEvent(
      serviceRequestId: serviceRequestId,
      clientEventId: clientEventId,
      reason: map['reason']?.toString() ?? '',
      createdAt:
          map['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      latitude: map['latitude']?.toString(),
      longitude: map['longitude']?.toString(),
      locationAccuracy: map['location_accuracy'] is num
          ? (map['location_accuracy'] as num).toDouble()
          : double.tryParse(map['location_accuracy']?.toString() ?? ''),
      locationCapturedAt: map['location_captured_at']?.toString(),
    );
  }
}

class PendingSosStore {
  PendingSosStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String storageKey = 'gowith_pending_sos_v1';
  final FlutterSecureStorage _storage;

  Future<List<PendingSosEvent>> _readAll() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return <PendingSosEvent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingSosEvent>[];
      return decoded
          .map(PendingSosEvent.fromJson)
          .whereType<PendingSosEvent>()
          .toList();
    } catch (_) {
      return <PendingSosEvent>[];
    }
  }

  Future<void> _writeAll(List<PendingSosEvent> events) async {
    if (events.isEmpty) {
      await _storage.delete(key: storageKey);
      return;
    }
    await _storage.write(
      key: storageKey,
      value: jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }

  Future<PendingSosEvent?> forService(int serviceRequestId) async {
    final events = await _readAll();
    for (final event in events.reversed) {
      if (event.serviceRequestId == serviceRequestId) return event;
    }
    return null;
  }

  Future<void> put(PendingSosEvent event) async {
    final events = List<PendingSosEvent>.of(await _readAll());
    events.removeWhere(
      (item) => item.serviceRequestId == event.serviceRequestId,
    );
    events.add(event);
    await _writeAll(events);
  }

  Future<void> remove(String clientEventId) async {
    final events = List<PendingSosEvent>.of(await _readAll());
    events.removeWhere((item) => item.clientEventId == clientEventId);
    await _writeAll(events);
  }

  Future<void> clearService(int serviceRequestId) async {
    final events = List<PendingSosEvent>.of(await _readAll());
    events.removeWhere((item) => item.serviceRequestId == serviceRequestId);
    await _writeAll(events);
  }
}
