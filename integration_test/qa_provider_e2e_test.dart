import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/core/network/token_storage.dart';
import 'package:gowith/main.dart' as app;

const qaProviderUser = String.fromEnvironment('QA_PROVIDER_USER');
const qaProviderPassword = String.fromEnvironment('QA_PROVIDER_PASSWORD');

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
  await tester.enterText(fields.at(0), qaProviderUser);
  await tester.enterText(fields.at(1), qaProviderPassword);
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
    // ProviderShell ejecuta _loadShellData() al seleccionar Cuenta y muestra
    // temporalmente CircularProgressIndicator. Se espera la pagina real.
    await pumpUntil(tester, find.text('Tu cuenta'));
  }
}

Future<void> dragUntilFound(
  WidgetTester tester, {
  required Finder dragSurface,
  required Finder target,
  int maxDrags = 12,
}) async {
  for (var attempt = 1; attempt <= maxDrags; attempt++) {
    if (target.evaluate().isNotEmpty) return;

    debugPrint('[QA] Cuenta: scroll intento $attempt/$maxDrags');
    await tester.drag(dragSurface, const Offset(0, -520));
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (target.evaluate().isEmpty) {
    throw TestFailure(
      'No se encontro Cerrar sesión despues de $maxDrags desplazamientos.',
    );
  }
}

Future<void> logoutFromAccount(WidgetTester tester) async {
  final accountHeader = find.text('Tu cuenta');
  await pumpUntil(tester, accountHeader);
  debugPrint('[QA] Cuenta prestador visible.');

  // El finder no debe depender de `Tu cuenta`: despues del primer scroll
  // ese encabezado puede salir del viewport y dejar de estar construido por
  // el ListView. Se usa el ListView que realmente recibe eventos tactiles;
  // los ListView de paginas ocultas dentro del IndexedStack quedan fuera.
  final accountList = find.byType(ListView).hitTestable();
  expect(
    accountList,
    findsOneWidget,
    reason: 'Debe existir un unico ListView visible en Cuenta prestador.',
  );
  debugPrint('[QA] ListView visible de Cuenta prestador localizado.');

  final logoutText = find.text('Cerrar sesión');
  await dragUntilFound(
    tester,
    dragSurface: accountList,
    target: logoutText,
  );

  expect(logoutText, findsOneWidget);
  debugPrint('[QA] Boton Cerrar sesión prestador visible.');
  await tester.tap(logoutText);
  await pumpUntil(tester, find.byType(AlertDialog));

  final confirmLogout = find.widgetWithText(FilledButton, 'Cerrar sesión');
  expect(confirmLogout, findsOneWidget);
  await tester.tap(confirmLogout);

  await pumpUntil(tester, find.text('Ingresar'));
  debugPrint('[QA] Logout prestador completado.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-PRO-001/002/003 login navegacion prestador y logout', (
    tester,
  ) async {
    if (qaProviderUser.isEmpty || qaProviderPassword.isEmpty) {
      throw TestFailure(
        'Faltan QA_PROVIDER_USER y/o QA_PROVIDER_PASSWORD como --dart-define.',
      );
    }

    await login(tester);

    for (final label in [
      'Actividades',
      'Histórico',
      'Ganancias',
      'Seguridad',
      'Cuenta',
    ]) {
      await tapDestination(tester, label);
      expect(find.text(label), findsWidgets);
    }

    expect(find.text('Tu cuenta'), findsOneWidget);
    await logoutFromAccount(tester);

    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
