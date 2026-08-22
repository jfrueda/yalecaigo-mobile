import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/core/network/token_storage.dart';
import 'package:gowith/main.dart' as app;

const qaClientUser = String.fromEnvironment('QA_CLIENT_USER');
const qaClientPassword = String.fromEnvironment('QA_CLIENT_PASSWORD');

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timeout esperando: $finder');
}

Future<void> login(WidgetTester tester) async {
  await TokenStorage.clearSession();
  await app.main();
  await pumpUntil(tester, find.text('Ingresar'));

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), qaClientUser);
  await tester.enterText(fields.at(1), qaClientPassword);
  await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
  await pumpUntil(tester, find.byType(NavigationBar));
}

Future<void> tapDestination(
  WidgetTester tester,
  String label,
) async {
  final destination = find.widgetWithText(NavigationDestination, label);
  expect(destination, findsOneWidget);
  await tester.tap(destination);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-CLI-001/002/003 login navegacion cliente y logout', (
    tester,
  ) async {
    if (qaClientUser.isEmpty || qaClientPassword.isEmpty) {
      throw TestFailure(
        'Faltan QA_CLIENT_USER y/o QA_CLIENT_PASSWORD como --dart-define.',
      );
    }

    await login(tester);

    expect(find.text('Inicio'), findsWidgets);
    for (final label in ['Actividades', 'Seguridad', 'Cuenta']) {
      await tapDestination(tester, label);
      expect(find.text(label), findsWidgets);
    }

    final logout = find.widgetWithText(FilledButton, 'Cerrar sesión');
    expect(logout, findsOneWidget);
    await tester.tap(logout);
    await pumpUntil(tester, find.byType(AlertDialog));
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await pumpUntil(tester, find.text('Ingresar'));

    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
