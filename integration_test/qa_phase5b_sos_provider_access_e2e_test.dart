import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/features/safety/data/sos_service.dart';

import 'qa_phase5b_helpers.dart';

const qaProviderUser = String.fromEnvironment('QA_PROVIDER_USER');
const qaProviderPassword = String.fromEnvironment('QA_PROVIDER_PASSWORD');
const requestIdRaw = String.fromEnvironment('QA_F5B_ONLINE_ID');
const incidentIdRaw = String.fromEnvironment('QA_F5B_ONLINE_INCIDENT_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F5B-E2E privacidad: contraparte no accede al SOS del cliente', (tester) async {
    final requestId = int.tryParse(requestIdRaw);
    final incidentId = int.tryParse(incidentIdRaw);
    if (requestId == null || incidentId == null) {
      throw TestFailure('Faltan IDs de SOS online para prueba de privacidad.');
    }

    await loginQa(tester, username: qaProviderUser, password: qaProviderPassword);
    final service = SosService();
    final active = await service.active(requestId);
    expect(active['active'], isNot(true), reason: 'El SOS activo del cliente no debe aparecer como propio del prestador.');

    try {
      await service.detail(incidentId);
      throw TestFailure('El prestador pudo leer un SOS activado por el cliente.');
    } on DioException catch (error) {
      expect(error.response?.statusCode, 403);
    }
    debugPrint('[QA-V3.1] Privacidad SOS validada: active=false y detail=403 para contraparte.');
  });
}
