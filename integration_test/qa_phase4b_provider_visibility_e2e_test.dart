import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'qa_phase4b_helpers.dart';

const qaProviderUser = String.fromEnvironment('QA_PROVIDER_USER');
const qaProviderPassword = String.fromEnvironment('QA_PROVIDER_PASSWORD');
const futureMarker = String.fromEnvironment('QA_F4B_FUTURE_MARKER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F4B-E2E-MATCH desbloqueo restaura visibilidad', (tester) async {
    if ([qaProviderUser, qaProviderPassword, futureMarker].any((v) => v.isEmpty)) {
      throw TestFailure('Faltan --dart-define para visibilidad post-desbloqueo.');
    }
    await loginQa(tester, username: qaProviderUser, password: qaProviderPassword);
    await pumpUntil(tester, find.text('Actividades disponibles'));
    await dragUntilVisibleText(tester, futureMarker, maxDrags: 18);
    expect(find.text(futureMarker), findsOneWidget);
    debugPrint('[QA-V2.1] Solicitud futura visible nuevamente despues del desbloqueo.');
  });
}
