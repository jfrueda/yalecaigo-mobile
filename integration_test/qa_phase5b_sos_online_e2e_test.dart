import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/features/safety/data/pending_sos_store.dart';
import 'package:gowith/features/safety/data/sos_service.dart';

import 'qa_phase5b_helpers.dart';

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');
const requestIdRaw = String.fromEnvironment('QA_F5B_ONLINE_ID');
const marker = String.fromEnvironment('QA_F5B_ONLINE_MARKER');
const reason = String.fromEnvironment('QA_F5B_ONLINE_REASON');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F5B-E2E SOS online y reenvio idempotente', (tester) async {
    final requestId = int.tryParse(requestIdRaw);
    if (requestId == null || marker.isEmpty || reason.isEmpty) {
      throw TestFailure('Faltan dart-defines de Fase 5B online.');
    }

    await PendingSosStore().clearService(requestId);
    await loginQa(tester, username: qaClientUser, password: qaClientPassword);
    await openClientService(tester, marker: marker, requestId: requestId);
    await activateSosFromUi(tester, reason: reason);

    await pumpUntil(
      tester,
      find.textContaining('Caso #'),
      timeout: const Duration(seconds: 45),
      reason: 'La UI no mostro el caso SOS confirmado por el servidor.',
    );
    await pumpUntil(tester, find.text('SOS manual'));
    expect(find.textContaining('Notificaciones:'), findsAtLeastNWidgets(1));

    final service = SosService();
    final active = await service.active(requestId);
    expect(active['active'], true);
    final incidentId = int.tryParse(active['id']?.toString() ?? '');
    final clientEventId = active['client_event_id']?.toString() ?? '';
    expect(incidentId, isNotNull);
    expect(clientEventId, isNotEmpty);

    final duplicate = await service.create(
      PendingSosEvent(
        serviceRequestId: requestId,
        clientEventId: clientEventId,
        reason: reason,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    expect(duplicate['received_by_server'], true);
    expect(duplicate['created'], false);
    expect(int.tryParse(duplicate['incident_id']?.toString() ?? ''), incidentId);
    debugPrint('[QA-V3.1] SOS online confirmado. incident=$incidentId client_event_id=$clientEventId');
  });
}
