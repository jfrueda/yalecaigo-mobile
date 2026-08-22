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
  await tester.pump(const Duration(milliseconds: 300));

  if (label == 'Cuenta') {
    // ClientShell vuelve a cargar perfil y solicitud activa al entrar a Cuenta.
    // Mientras esa carga esta en curso, AccountOverviewPage aun no existe.
    await pumpUntil(tester, find.text('Tu cuenta'));
  }
}

Future<void> logoutFromAccount(WidgetTester tester) async {
  final accountHeader = find.text('Tu cuenta');
  await pumpUntil(tester, accountHeader);

  // Identifica exclusivamente el ListView que contiene el encabezado de
  // AccountOverviewPage. ListView no puede pasarse directamente como
  // scrollable a scrollUntilVisible: Flutter espera el Scrollable interno.
  final accountList = find.ancestor(
    of: accountHeader,
    matching: find.byType(ListView),
  );
  expect(accountList, findsOneWidget);

  final accountScrollable = find.descendant(
    of: accountList,
    matching: find.byType(Scrollable),
  );
  expect(accountScrollable, findsOneWidget);

  final logoutText = find.text('Cerrar sesión');
  await tester.scrollUntilVisible(
    logoutText,
    500,
    scrollable: accountScrollable,
    maxScrolls: 20,
  );
  await tester.pump(const Duration(milliseconds: 300));

  expect(logoutText, findsOneWidget);
  await tester.tap(logoutText);
  await pumpUntil(tester, find.byType(AlertDialog));

  final confirmLogout = find.widgetWithText(FilledButton, 'Cerrar sesión');
  expect(confirmLogout, findsOneWidget);
  await tester.tap(confirmLogout);

  await pumpUntil(tester, find.text('Ingresar'));
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

    expect(find.text('Tu cuenta'), findsOneWidget);
    await logoutFromAccount(tester);

    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
