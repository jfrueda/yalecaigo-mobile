import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'qa_phase4b_helpers.dart';

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');
const finishedMarker = String.fromEnvironment('QA_F4B_FINISHED_MARKER');
const finishedId = String.fromEnvironment('QA_F4B_FINISHED_ID');
const publicComment = String.fromEnvironment('QA_F4B_PUBLIC_COMMENT');
const privateComment = String.fromEnvironment('QA_F4B_PRIVATE_COMMENT');
const reportDescription = String.fromEnvironment('QA_F4B_REPORT_DESCRIPTION');
const blockReason = String.fromEnvironment('QA_F4B_BLOCK_REASON');
const providerUsername = String.fromEnvironment('QA_F4B_PROVIDER_USERNAME');

void requireDefines() {
  final values = {
    'QA_CLIENT_USER': qaClientUser,
    'QA_CLIENT_PASSWORD': qaClientPassword,
    'QA_F4B_FINISHED_MARKER': finishedMarker,
    'QA_F4B_FINISHED_ID': finishedId,
    'QA_F4B_PUBLIC_COMMENT': publicComment,
    'QA_F4B_PRIVATE_COMMENT': privateComment,
    'QA_F4B_REPORT_DESCRIPTION': reportDescription,
    'QA_F4B_BLOCK_REASON': blockReason,
    'QA_F4B_PROVIDER_USERNAME': providerUsername,
  };
  for (final entry in values.entries) {
    if (entry.value.isEmpty) throw TestFailure('Falta --dart-define ${entry.key}.');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F4B-E2E-CLIENT rating report block y lista de bloqueados', (tester) async {
    requireDefines();
    await loginQa(tester, username: qaClientUser, password: qaClientPassword);

    await tapDestination(tester, 'Actividades', waitForText: 'Tus actividades');
    await tapTextAfterScroll(tester, finishedMarker, maxDrags: 18);
    await pumpUntil(tester, find.text('Solicitud #$finishedId'));
    await pumpUntil(tester, find.text('Actividad finalizada'));
    debugPrint('[QA-V2.1.1] Cliente abrio servicio finalizado $finishedId.');

    await tapTextAfterScroll(tester, 'Calificar al acompañante', maxDrags: 14);
    await pumpUntil(tester, find.text('Enviar calificación'));
    final ratingFields = find.byType(TextField);
    expect(ratingFields, findsNWidgets(2));
    await tester.enterText(ratingFields.at(0), publicComment);
    await tester.enterText(ratingFields.at(1), privateComment);
    await tester.tap(find.text('Enviar calificación'));
    await pumpUntil(tester, find.text('Tu calificación: 5/5'));
    expect(find.text('Pendiente de moderación'), findsOneWidget);
    debugPrint('[QA-V2.1.1] Cliente registro calificacion 5/5.');

    await tapTextAfterScroll(tester, 'Ver reputación del acompañante', maxDrags: 8);
    await pumpUntil(tester, find.text('Reputación del acompañante'));
    expect(
      find.textContaining(publicComment),
      findsNothing,
      reason: 'El comentario pendiente no debe mostrarse como reseña pública.',
    );
    await tester.pageBack();
    await pumpUntil(tester, find.text('Solicitud #$finishedId'));
    debugPrint('[QA-V2.1.1] Reputacion abre sin publicar comentario pendiente.');

    await tapTextAfterScroll(tester, 'Reportar comportamiento', maxDrags: 12);
    await pumpUntil(
      tester,
      find.byType(AlertDialog),
      reason: 'No se abrio el dialogo Reportar comportamiento.',
    );
    await pumpUntil(
      tester,
      find.byType(TextField),
      reason: 'El dialogo de reporte abrio sin su campo de detalle.',
    );
    final reportFields = find.byType(TextField);
    expect(reportFields, findsOneWidget);
    await tester.enterText(reportFields.first, reportDescription);
    await tester.tap(find.text('Enviar reporte').hitTestable());
    await pumpUntil(tester, find.text('Reporte enviado de forma privada a GoWith.'));
    debugPrint('[QA-V2.1.1] Cliente creo reporte privado.');

    await tapTextAfterScroll(tester, 'Bloquear acompañante', maxDrags: 8);
    await pumpUntil(tester, find.text('Bloquear usuario'));
    final blockFields = find.byType(TextField);
    expect(blockFields, findsOneWidget);
    await tester.enterText(blockFields.first, blockReason);
    await tester.tap(find.text('Bloquear').hitTestable());
    await pumpUntil(
      tester,
      find.text('Usuario bloqueado. No volverán a ser emparejados en nuevas actividades.'),
    );
    debugPrint('[QA-V2.1.1] Cliente bloqueo prestador.');

    await tester.pageBack();
    await pumpUntil(tester, find.byType(NavigationBar));
    await openAccountMenuItem(tester, 'Usuarios bloqueados');
    await pumpUntil(tester, find.text('Usuarios bloqueados'));
    await pumpUntil(tester, find.text(providerUsername));
    expect(find.text('Motivo: $blockReason'), findsOneWidget);
    debugPrint('[QA-V2.1.1] Bloqueo visible en Cuenta > Usuarios bloqueados.');
  });
}
