import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';
import 'package:gowith/features/safety/data/pending_sos_store.dart';
import 'package:gowith/features/safety/data/sos_service.dart';

void main() {
  group('Fase 5B - contrato SOS', () {
    test('expone endpoints de creación, estado activo y detalle', () {
      expect(Endpoints.sos, '/security/sos/');
      expect(Endpoints.activeSos, '/security/sos/active/');
      expect(Endpoints.sosDetail(15), '/security/sos/15/');
    });

    test('coordenadas SOS usan seis decimales', () {
      expect(formatSosCoordinate(4.6767123456), '4.676712');
      expect(formatSosCoordinate(-74.0482129876), '-74.048213');
    });

    test('client_event_id es UUID v4 válido para reintentos idempotentes', () {
      final id = newSosClientEventId();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('evento pendiente conserva payload necesario para reintentar', () {
      const event = PendingSosEvent(
        serviceRequestId: 42,
        clientEventId: '123e4567-e89b-42d3-a456-426614174000',
        reason: 'Prueba',
        createdAt: '2026-08-21T00:00:00Z',
        latitude: '4.676712',
        longitude: '-74.048213',
        locationAccuracy: 8.5,
        locationCapturedAt: '2026-08-21T00:00:00Z',
      );
      final restored = PendingSosEvent.fromJson(event.toJson());
      expect(restored, isNotNull);
      expect(restored!.serviceRequestId, 42);
      expect(restored.clientEventId, event.clientEventId);
      expect(restored.toApiPayload()['latitude'], '4.676712');
      expect(restored.toApiPayload()['longitude'], '-74.048213');
    });
  });
}
