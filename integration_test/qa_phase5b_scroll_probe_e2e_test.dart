import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'qa_phase5b_helpers.dart';

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');
const requestIdRaw = String.fromEnvironment('QA_F5B_ONLINE_ID');
const marker = String.fromEnvironment('QA_F5B_ONLINE_MARKER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F5B-SCROLL-PROBE tracking timer y SOS visibles', (tester) async {
    final requestId = int.tryParse(requestIdRaw);
    if (requestId == null || marker.isEmpty) {
      throw TestFailure('Faltan dart-defines del scroll probe Fase 5B.');
    }

    await loginQa(
      tester,
      username: qaClientUser,
      password: qaClientPassword,
    );
    await openClientServiceDetail(
      tester,
      marker: marker,
      requestId: requestId,
    );

    await ensureTextVisible(tester, 'Ubicación y seguridad', maxDrags: 12);
    expect(find.text('Ubicación y seguridad').hitTestable(), findsOneWidget);
    debugPrint('[QA-V3.1.2][PROBE] PASS Ubicación y seguridad');

    await ensureTextVisible(tester, 'Temporizador de seguridad', maxDrags: 12);
    expect(find.text('Temporizador de seguridad').hitTestable(), findsOneWidget);
    debugPrint('[QA-V3.1.2][PROBE] PASS Temporizador de seguridad');

    await ensureTextVisible(tester, 'SOS y escalamiento', maxDrags: 12);
    expect(find.text('SOS y escalamiento').hitTestable(), findsOneWidget);
    debugPrint('[QA-V3.1.2][PROBE] PASS SOS y escalamiento');

    expect(find.text('ACTIVAR SOS'), findsAtLeastNWidgets(1));
    debugPrint('[QA-V3.1.2][PROBE] PASS ACTIVAR SOS construido');
  });
}
