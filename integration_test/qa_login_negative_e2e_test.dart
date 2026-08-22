import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/core/network/token_storage.dart';
import 'package:gowith/main.dart' as app;

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timeout esperando: $finder');
}

Future<void> launchFresh(WidgetTester tester) async {
  await TokenStorage.clearSession();
  await app.main();
  await pumpUntil(tester, find.text('Ingresar'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-AUTH-001/002 login visible y credenciales invalidas rechazadas', (
    tester,
  ) async {
    if (qaClientUser.isEmpty) {
      throw TestFailure(
        'Falta --dart-define=QA_CLIENT_USER=<usuario_cliente_pruebas>.',
      );
    }

    await launchFresh(tester);

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Correo, celular o usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), qaClientUser);
    await tester.enterText(fields.at(1), 'QA_PASSWORD_INVALIDA_2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));

    await pumpUntil(tester, find.widgetWithText(FilledButton, 'Ingresar'));
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
  });
}
