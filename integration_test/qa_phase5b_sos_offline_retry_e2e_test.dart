import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/core/network/api_client.dart';
import 'package:gowith/features/safety/data/pending_sos_store.dart';
import 'package:gowith/features/safety/data/sos_service.dart';

import 'qa_phase5b_helpers.dart';

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');
const requestIdRaw = String.fromEnvironment('QA_F5B_OFFLINE_ID');
const marker = String.fromEnvironment('QA_F5B_OFFLINE_MARKER');
const reason = String.fromEnvironment('QA_F5B_OFFLINE_REASON');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F5B-E2E transporte offline, cola local y retry idempotente', (tester) async {
    final requestId = int.tryParse(requestIdRaw);
    if (requestId == null || marker.isEmpty || reason.isEmpty) {
      throw TestFailure('Faltan dart-defines de Fase 5B offline.');
    }

    final store = PendingSosStore();
    await store.clearService(requestId);
    await loginQa(tester, username: qaClientUser, password: qaClientPassword);
    await openClientService(tester, marker: marker, requestId: requestId);

    final dio = ApiClient.dio;
    final originalBaseUrl = dio.options.baseUrl;
    final originalConnect = dio.options.connectTimeout;
    final originalSend = dio.options.sendTimeout;
    final originalReceive = dio.options.receiveTimeout;
    PendingSosEvent? pending;

    try {
      dio.options.baseUrl = 'http://127.0.0.1:9/api';
      dio.options.connectTimeout = const Duration(seconds: 1);
      dio.options.sendTimeout = const Duration(seconds: 1);
      dio.options.receiveTimeout = const Duration(seconds: 1);

      await activateSosFromUi(tester, reason: reason);
      await pumpUntil(
        tester,
        find.text('SOS pendiente de envío'),
        timeout: const Duration(seconds: 35),
        reason: 'La UI no conservo el SOS al fallar el transporte.',
      );
      pending = await store.forService(requestId);
      expect(pending, isNotNull);
      expect(pending!.clientEventId, isNotEmpty);
      debugPrint('[QA-V3.1] SOS offline persistido localmente: ${pending!.clientEventId}');
    } finally {
      dio.options.baseUrl = originalBaseUrl;
      dio.options.connectTimeout = originalConnect;
      dio.options.sendTimeout = originalSend;
      dio.options.receiveTimeout = originalReceive;
    }

    await tester.tap(find.text('Reintentar ahora').hitTestable().first);
    await pumpUntil(
      tester,
      find.textContaining('Caso #'),
      timeout: const Duration(seconds: 45),
      reason: 'El retry no obtuvo confirmacion del servidor.',
    );
    await pumpUntil(tester, find.text('SOS manual'));

    final after = await store.forService(requestId);
    expect(after, isNull, reason: 'La cola local debe limpiarse luego de received_by_server=true.');

    final service = SosService();
    final active = await service.active(requestId);
    expect(active['active'], true);
    final incidentId = int.tryParse(active['id']?.toString() ?? '');
    expect(incidentId, isNotNull);
    expect(active['client_event_id']?.toString(), pending!.clientEventId);

    final duplicate = await service.create(pending!);
    expect(duplicate['received_by_server'], true);
    expect(duplicate['created'], false);
    expect(int.tryParse(duplicate['incident_id']?.toString() ?? ''), incidentId);
    debugPrint('[QA-V3.1] Retry offline confirmado sin duplicado. incident=$incidentId client_event_id=${pending!.clientEventId}');
  });
}
