import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';
import 'package:gowith/features/tracking/data/device_location_service.dart';

void main() {
  group('Fase 5A - contrato de tracking', () {
    test('expone endpoints de seguimiento, compartir y temporizador', () {
      expect(Endpoints.trackingRequest(42), '/services/requests/42/tracking/');
      expect(Endpoints.shareRequest(42), '/services/requests/42/share/');
      expect(
        Endpoints.safetyTimerRequest(42),
        '/services/requests/42/safety-timer/',
      );
      expect(Endpoints.sharedActivity('abc123'), '/services/shared/abc123/');
    });

    test('los errores de ubicación conservan un mensaje utilizable', () {
      const error = DeviceLocationException('GPS requerido');
      expect(error.message, 'GPS requerido');
      expect(error.toString(), 'GPS requerido');
    });
  });
}
