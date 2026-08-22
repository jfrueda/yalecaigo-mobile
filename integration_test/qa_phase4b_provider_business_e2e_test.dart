import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'qa_phase4b_helpers.dart';

const qaProviderUser = String.fromEnvironment('QA_PROVIDER_USER');
const qaProviderPassword = String.fromEnvironment('QA_PROVIDER_PASSWORD');
const finishedMarker = String.fromEnvironment('QA_F4B_FINISHED_MARKER');
const futureMarker = String.fromEnvironment('QA_F4B_FUTURE_MARKER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F4B-E2E-PROVIDER bloqueo excluye matching y rating mutuo', (tester) async {
    if ([qaProviderUser, qaProviderPassword, finishedMarker, futureMarker].any((v) => v.isEmpty)) {
      throw TestFailure('Faltan --dart-define para el escenario Fase 4B prestador.');
    }

    await loginQa(tester, username: qaProviderUser, password: qaProviderPassword);
    await pumpUntil(tester, find.text('Actividades disponibles'));
    expect(
      find.text(futureMarker),
      findsNothing,
      reason: 'La solicitud futura debe estar excluida del matching mientras exista bloqueo.',
    );
    debugPrint('[QA-V2.1] Solicitud futura no visible durante bloqueo.');

    await tapDestination(tester, 'Histórico', waitForText: 'Histórico de actividades');
    await tapTextAfterScroll(tester, finishedMarker, maxDrags: 18);
    await pumpUntil(tester, find.text('Detalle de actividad'));

    await tapTextAfterScroll(tester, 'Calificar solicitante', maxDrags: 14);
    await pumpUntil(tester, find.text('Enviar calificación'));
    final fourStars = find.byTooltip('4 estrellas');
    expect(fourStars, findsOneWidget);
    await tester.tap(fourStars);
    await tester.tap(find.text('Enviar calificación'));
    await pumpUntil(tester, find.text('Tu calificación al solicitante: 4/5'));
    debugPrint('[QA-V2.1] Prestador registro calificacion 4/5.');
  });
}
