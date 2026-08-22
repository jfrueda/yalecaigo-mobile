import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/token_storage.dart';
import 'package:gowith/main.dart' as app;

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 35),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(reason ?? 'Timeout esperando: $finder');
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 35),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure(reason ?? 'Timeout esperando desaparicion: $finder');
}

Future<void> loginQa(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  if (username.isEmpty || password.isEmpty) {
    throw TestFailure('Credenciales QA vacias.');
  }
  await TokenStorage.clearSession();
  await app.main();
  await pumpUntil(tester, find.text('Ingresar'));

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
  await pumpUntil(tester, find.byType(NavigationBar));
}

Future<void> tapDestination(
  WidgetTester tester,
  String label, {
  String? waitForText,
}) async {
  final destination = find.widgetWithText(NavigationDestination, label);
  expect(destination, findsOneWidget, reason: 'Destino no encontrado: $label');
  await tester.tap(destination);
  await tester.pump(const Duration(milliseconds: 300));
  if (waitForText != null) {
    await pumpUntil(tester, find.text(waitForText));
  }
}

Finder visibleListView() => find.byType(ListView).hitTestable().first;

Finder _textFinder(String text, {required bool containing}) {
  return containing ? find.textContaining(text) : find.text(text);
}

Future<void> dragUntilVisibleText(
  WidgetTester tester,
  String text, {
  int maxDrags = 16,
  double dy = -500,
  bool containing = false,
}) async {
  final target = _textFinder(text, containing: containing);

  for (var attempt = 0; attempt <= maxDrags; attempt++) {
    final interactiveTarget = target.hitTestable();
    if (interactiveTarget.evaluate().isNotEmpty) {
      if (attempt > 0) {
        debugPrint('[QA-V2.1.1] objetivo interactuable despues de $attempt scroll(s): $text');
      }
      return;
    }

    if (attempt == maxDrags) break;

    final surface = visibleListView();
    if (surface.evaluate().isEmpty) {
      debugPrint('[QA-V2.1.1] ListView interactuable no disponible; esperando: $text');
      await tester.pump(const Duration(milliseconds: 250));
      continue;
    }

    debugPrint('[QA-V2.1.1] scroll ${attempt + 1}/$maxDrags buscando control interactuable: $text');
    await tester.drag(surface, Offset(0, dy));
    await tester.pump(const Duration(milliseconds: 350));
  }

  final built = target.evaluate().isNotEmpty;
  throw TestFailure(
    built
        ? 'Se encontro "$text" en el arbol, pero no quedo interactuable despues de $maxDrags desplazamientos.'
        : 'No se encontro "$text" despues de $maxDrags desplazamientos.',
  );
}

Future<void> tapTextAfterScroll(
  WidgetTester tester,
  String text, {
  int maxDrags = 16,
}) async {
  await dragUntilVisibleText(tester, text, maxDrags: maxDrags);
  final target = find.text(text).hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'El texto "$text" existe pero no esta disponible para tap.',
  );
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}


Future<void> tapVisibleBack(
  WidgetTester tester, {
  String? waitForText,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  Finder visibleBack = find.byTooltip('Back').hitTestable();

  while (DateTime.now().isBefore(end) && visibleBack.evaluate().isEmpty) {
    await tester.pump(const Duration(milliseconds: 250));
    visibleBack = find.byTooltip('Back').hitTestable();
  }

  if (visibleBack.evaluate().isEmpty) {
    throw TestFailure('No se encontro un boton Back interactuable.');
  }

  final count = visibleBack.evaluate().length;
  debugPrint('[QA-V2.1.3] botones Back interactuables encontrados: $count; se usara el primero.');
  await tester.tap(visibleBack.first);
  await tester.pump(const Duration(milliseconds: 350));

  if (waitForText != null) {
    await pumpUntil(tester, find.text(waitForText));
  }
}

Future<void> openAccountMenuItem(
  WidgetTester tester,
  String text,
) async {
  await tapDestination(tester, 'Cuenta', waitForText: 'Tu cuenta');
  await tapTextAfterScroll(tester, text, maxDrags: 14);
}
