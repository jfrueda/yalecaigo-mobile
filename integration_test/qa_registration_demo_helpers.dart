import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> demoPause(WidgetTester tester, [int milliseconds = 700]) async {
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
  await tester.pump();
}

Future<void> pumpNetwork(WidgetTester tester, [int milliseconds = 350]) async {
  final deadline = DateTime.now().add(Duration(milliseconds: milliseconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

Future<bool> waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (predicate()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return predicate();
}

Future<Map<String, dynamic>> qaBridgeGet(
  String baseUrl,
  String path,
  Map<String, String> query,
) async {
  final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('QA bridge ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw StateError('Respuesta QA bridge inválida: $body');
    return Map<String, dynamic>.from(decoded);
  } finally {
    client.close(force: true);
  }
}

Finder inputDecoratorByLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is InputDecorator && widget.decoration.labelText == label,
  description: 'InputDecorator(label=$label)',
);

Future<ScrollPosition?> mainVerticalPosition(WidgetTester tester) async {
  final finder = find.byType(Scrollable).hitTestable();
  ScrollPosition? best;
  double bestExtent = -1;
  for (var i = 0; i < finder.evaluate().length; i++) {
    try {
      final state = tester.state<ScrollableState>(finder.at(i));
      final position = state.position;
      final vertical = position.axis == Axis.vertical;
      if (vertical && position.maxScrollExtent > bestExtent) {
        best = position;
        bestExtent = position.maxScrollExtent;
      }
    } catch (_) {
      // Ignora scrollables transitorios.
    }
  }
  return best;
}

Future<void> scrollDown(WidgetTester tester, [double amount = 420]) async {
  final position = await mainVerticalPosition(tester);
  if (position == null) return;
  final target = math.min(position.maxScrollExtent, position.pixels + amount);
  if ((target - position.pixels).abs() < 0.5) return;
  position.jumpTo(target);
  await tester.pump(const Duration(milliseconds: 220));
}

Future<void> scrollTop(WidgetTester tester) async {
  final position = await mainVerticalPosition(tester);
  if (position == null) return;
  position.jumpTo(position.minScrollExtent);
  await tester.pump(const Duration(milliseconds: 220));
}

Future<bool> ensureTextVisible(
  WidgetTester tester,
  String text, {
  int maxScrolls = 16,
}) async {
  for (var i = 0; i <= maxScrolls; i++) {
    final visible = find.text(text).hitTestable();
    if (visible.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(visible.first);
        await tester.pump(const Duration(milliseconds: 150));
      } catch (_) {}
      return true;
    }
    await scrollDown(tester);
  }
  return false;
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  int maxScrolls = 16,
}) async {
  final ok = await ensureTextVisible(tester, text, maxScrolls: maxScrolls);
  if (!ok) throw TestFailure('No se encontró texto visible: $text');
  final finder = find.text(text).hitTestable();
  await tester.tap(finder.last);
  await pumpNetwork(tester, 500);
}

Future<void> enterByLabel(
  WidgetTester tester,
  String label,
  String value, {
  int maxScrolls = 16,
}) async {
  for (var i = 0; i <= maxScrolls; i++) {
    final decorators = inputDecoratorByLabel(label).hitTestable();
    if (decorators.evaluate().isNotEmpty) {
      final editable = find.descendant(
        of: decorators.last,
        matching: find.byType(EditableText),
      );
      if (editable.evaluate().isEmpty) {
        throw TestFailure('El campo $label no contiene EditableText.');
      }
      await tester.tap(editable.first);
      await tester.enterText(editable.first, value);
      await tester.pump(const Duration(milliseconds: 160));
      return;
    }
    await scrollDown(tester);
  }
  throw TestFailure('No se encontró campo: $label');
}


Future<bool> _dropdownHasIntValue(WidgetTester tester, int value) async {
  final buttons = find.byWidgetPredicate(
    (widget) => widget is DropdownButton<int>,
    description: 'DropdownButton<int> con valor $value',
  );
  for (var i = 0; i < buttons.evaluate().length; i++) {
    try {
      final button = tester.widget<DropdownButton<int>>(buttons.at(i));
      final items = button.items ?? const <DropdownMenuItem<int>>[];
      if (items.any((item) => item.value == value)) return true;
    } catch (_) {}
  }
  return false;
}

Future<void> chooseIntDropdownByValue(
  WidgetTester tester,
  String label,
  int value, {
  int maxScrolls = 16,
  Duration waitForItems = const Duration(seconds: 8),
}) async {
  for (var i = 0; i <= maxScrolls; i++) {
    final decorators = inputDecoratorByLabel(label).hitTestable();
    if (decorators.evaluate().isNotEmpty) {
      final deadline = DateTime.now().add(waitForItems);
      while (DateTime.now().isBefore(deadline)) {
        if (await _dropdownHasIntValue(tester, value)) break;
        await pumpNetwork(tester, 250);
      }
      if (!await _dropdownHasIntValue(tester, value)) {
        throw TestFailure(
          'El selector "$label" no cargó el ID geográfico $value.',
        );
      }

      await tester.tap(decorators.last);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final item = find.byWidgetPredicate(
        (widget) => widget is DropdownMenuItem<int> && widget.value == value,
        description: 'DropdownMenuItem<int>(value=$value)',
      );
      if (item.evaluate().isEmpty) {
        throw TestFailure(
          'El menú "$label" abrió, pero no construyó el ID $value.',
        );
      }

      // El elemento puede estar fuera del viewport del overlay del dropdown.
      // ensureVisible desplaza el scroll interno del menú, no la página principal.
      try {
        await tester.ensureVisible(item.last);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      } catch (_) {}

      final visible = find.byWidgetPredicate(
        (widget) => widget is DropdownMenuItem<int> && widget.value == value,
        description: 'DropdownMenuItem<int> visible(value=$value)',
      ).hitTestable();
      if (visible.evaluate().isEmpty) {
        throw TestFailure(
          'El ID $value existe en "$label", pero no se pudo hacer visible.',
        );
      }

      await tester.tap(visible.last);
      await pumpNetwork(tester, 900);
      debugPrint('[QA-DEMO] $label seleccionado por ID estable: $value');
      return;
    }
    await scrollDown(tester);
  }
  throw TestFailure('No se encontró selector: $label');
}

Future<void> chooseDropdown(
  WidgetTester tester,
  String label,
  String option, {
  int maxScrolls = 16,
}) async {
  for (var i = 0; i <= maxScrolls; i++) {
    final decorators = inputDecoratorByLabel(label).hitTestable();
    if (decorators.evaluate().isNotEmpty) {
      await tester.tap(decorators.last);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final exact = find.text(option).hitTestable();
      if (exact.evaluate().isNotEmpty) {
        await tester.tap(exact.last);
      } else {
        final partial = find.textContaining(option).hitTestable();
        if (partial.evaluate().isEmpty) {
          throw TestFailure('No se encontró opción "$option" para $label');
        }
        await tester.tap(partial.last);
      }
      await pumpNetwork(tester, 650);
      return;
    }
    await scrollDown(tester);
  }
  throw TestFailure('No se encontró selector: $label');
}

Future<void> chooseBirthDate(WidgetTester tester) async {
  await tapText(tester, 'Seleccionar fecha');
  await tester.pumpAndSettle(const Duration(milliseconds: 100));

  Finder year = find.text('2000').hitTestable();
  if (year.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          find.text('2000'),
          250,
          scrollable: scrollables.last,
          maxScrolls: 10,
        );
      } catch (_) {}
    }
    year = find.text('2000').hitTestable();
  }
  if (year.evaluate().isEmpty) {
    throw TestFailure('No se pudo seleccionar el año 2000.');
  }
  await tester.tap(year.last);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));

  final day = find.text('15').hitTestable();
  if (day.evaluate().isNotEmpty) {
    await tester.tap(day.last);
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tapText(tester, 'Aceptar', maxScrolls: 0);
}

Future<void> acceptLegal(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    final title = find
        .text(
          'Acepto los Términos, la Política de privacidad y el tratamiento de mis datos.',
        )
        .hitTestable();
    if (title.evaluate().isNotEmpty) {
      final tile = find.ancestor(of: title.first, matching: find.byType(CheckboxListTile));
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first);
      } else {
        await tester.tap(title.first);
      }
      await tester.pump(const Duration(milliseconds: 180));
      return;
    }
    await scrollDown(tester);
  }
  throw TestFailure('No se encontró aceptación de documentos legales.');
}

Future<bool> automateOtp(
  WidgetTester tester,
  String code,
) async {
  await pumpNetwork(tester, 700);
  final editables = find.byType(EditableText).hitTestable();
  final count = editables.evaluate().length;
  if (count == 0) return false;

  if (count >= 6) {
    for (var i = 0; i < 6; i++) {
      await tester.tap(editables.at(i));
      await tester.enterText(editables.at(i), code[i]);
      await tester.pump(const Duration(milliseconds: 80));
    }
  } else {
    await tester.tap(editables.last);
    await tester.enterText(editables.last, code);
    await tester.pump(const Duration(milliseconds: 150));
  }

  const actions = [
    'Verificar código',
    'Verificar correo',
    'Confirmar código',
    'Confirmar correo',
    'Verificar',
    'Confirmar',
    'Continuar',
  ];
  for (final action in actions) {
    final finder = find.text(action).hitTestable();
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.last);
      await pumpNetwork(tester, 1000);
      return true;
    }
  }

  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpNetwork(tester, 900);
  return true;
}

Future<void> ensureProviderActivitySelected(WidgetTester tester) async {
  final reached = await ensureTextVisible(tester, 'Actividades');
  if (!reached) throw TestFailure('No se encontró sección Actividades.');
  await pumpNetwork(tester, 400);

  final checkboxes = find.byType(Checkbox);
  var anySelected = false;
  for (var i = 0; i < checkboxes.evaluate().length; i++) {
    final widget = tester.widget<Checkbox>(checkboxes.at(i));
    if (widget.value == true) {
      anySelected = true;
      break;
    }
  }
  if (anySelected) return;

  // Busca el primer checkbox de categoría mientras baja por la lista.
  for (var attempt = 0; attempt < 8; attempt++) {
    final visible = find.byType(Checkbox).hitTestable();
    if (visible.evaluate().isNotEmpty) {
      await tester.tap(visible.first);
      await pumpNetwork(tester, 400);
      return;
    }
    await scrollDown(tester, 300);
  }
  throw TestFailure('No hay actividades disponibles para seleccionar.');
}
