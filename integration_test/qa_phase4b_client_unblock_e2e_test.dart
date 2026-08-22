import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'qa_phase4b_helpers.dart';

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');
const finishedMarker = String.fromEnvironment('QA_F4B_FINISHED_MARKER');
const finishedId = String.fromEnvironment('QA_F4B_FINISHED_ID');
const publicComment = String.fromEnvironment('QA_F4B_PUBLIC_COMMENT');
const providerUsername = String.fromEnvironment('QA_F4B_PROVIDER_USERNAME');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F4B-E2E-CLIENT reputacion moderada y desbloqueo', (tester) async {
    if ([qaClientUser, qaClientPassword, finishedMarker, finishedId, publicComment, providerUsername].any((v) => v.isEmpty)) {
      throw TestFailure('Faltan --dart-define para reputacion/desbloqueo Fase 4B.');
    }

    await loginQa(tester, username: qaClientUser, password: qaClientPassword);
    await tapDestination(tester, 'Actividades', waitForText: 'Tus actividades');
    await tapTextAfterScroll(tester, finishedMarker, maxDrags: 18);
    await pumpUntil(tester, find.text('Solicitud #$finishedId'));
    await pumpUntil(tester, find.text('Actividad finalizada'));

    await tapTextAfterScroll(tester, 'Ver reputación del acompañante', maxDrags: 14);
    await pumpUntil(tester, find.text('Reputación del acompañante'));
    await dragUntilVisibleText(tester, publicComment, maxDrags: 10, containing: true);
    expect(find.textContaining(publicComment), findsOneWidget);
    debugPrint('[QA-V2.1.3] Comentario aprobado visible en reputacion.');

    await tapVisibleBack(tester, waitForText: 'Solicitud #$finishedId');
    await tapVisibleBack(tester);
    await pumpUntil(tester, find.byType(NavigationBar));
    debugPrint('[QA-V2.1.3] Regreso desde reputacion a Actividades completado.');

    await openAccountMenuItem(tester, 'Usuarios bloqueados');
    await pumpUntil(tester, find.text('Usuarios bloqueados'));
    await pumpUntil(tester, find.text(providerUsername));
    final providerTile = find.ancestor(
      of: find.text(providerUsername),
      matching: find.byType(ListTile),
    );
    expect(providerTile, findsOneWidget);
    final unblock = find.descendant(
      of: providerTile,
      matching: find.text('Desbloquear'),
    );
    expect(unblock, findsOneWidget);
    await tester.tap(unblock);
    await pumpUntil(tester, find.text('Desbloquear usuario'));
    final confirm = find.widgetWithText(FilledButton, 'Desbloquear');
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await pumpUntilGone(
      tester,
      find.text(providerUsername),
      reason: 'El prestador sigue apareciendo en la lista de bloqueados.',
    );
    debugPrint('[QA-V2.1.3] Cliente desbloqueo prestador desde Cuenta.');
  });
}
