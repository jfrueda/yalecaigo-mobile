import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/token_storage.dart';
import 'package:gowith/main.dart' as app;

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(reason ?? 'Timeout esperando: $finder');
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
  await tester.pump(const Duration(milliseconds: 350));
  if (waitForText != null) {
    await pumpUntil(tester, find.text(waitForText));
  }
}

Finder _interactiveText(String text) => find.text(text).hitTestable();

class _VerticalScrollCandidate {
  const _VerticalScrollCandidate({
    required this.finder,
    required this.position,
    required this.index,
  });

  final Finder finder;
  final ScrollPosition position;
  final int index;
}

_VerticalScrollCandidate? _primaryVerticalScroll(WidgetTester tester) {
  final scrollables = find.byType(Scrollable);
  final count = scrollables.evaluate().length;
  _VerticalScrollCandidate? best;

  for (var index = 0; index < count; index++) {
    final finder = scrollables.at(index);
    try {
      final state = tester.state<ScrollableState>(finder);
      final position = state.position;
      if (axisDirectionToAxis(position.axisDirection) != Axis.vertical) {
        continue;
      }
      if (!position.hasPixels || !position.hasContentDimensions) {
        continue;
      }
      if (best == null ||
          position.maxScrollExtent > best.position.maxScrollExtent) {
        best = _VerticalScrollCandidate(
          finder: finder,
          position: position,
          index: index,
        );
      }
    } catch (_) {
      // Un Scrollable que se desmonta durante un rebuild no debe abortar QA.
    }
  }
  return best;
}

String _scrollMetrics(_VerticalScrollCandidate? candidate) {
  if (candidate == null) return 'scrollable=NONE';
  final position = candidate.position;
  return 'scrollable=${candidate.index} '
      'pixels=${position.pixels.toStringAsFixed(1)} '
      'min=${position.minScrollExtent.toStringAsFixed(1)} '
      'max=${position.maxScrollExtent.toStringAsFixed(1)}';
}

Future<bool> _programmaticScrollStep(
  WidgetTester tester, {
  required String targetText,
  required int attempt,
  required int maxAttempts,
  required double dy,
}) async {
  var candidate = _primaryVerticalScroll(tester);
  if (candidate == null) {
    await tester.pump(const Duration(milliseconds: 300));
    candidate = _primaryVerticalScroll(tester);
  }
  if (candidate == null) {
    debugPrint(
      '[QA-V3.1.2][SCROLL] intento $attempt/$maxAttempts '
      'target="$targetText" scrollable=NONE',
    );
    return false;
  }

  final position = candidate.position;
  final before = position.pixels;
  final max = position.maxScrollExtent;
  final min = position.minScrollExtent;
  final delta = dy.abs();
  final target = dy < 0
      ? math.min(before + delta, max)
      : math.max(before - delta, min);

  debugPrint(
    '[QA-V3.1.2][SCROLL] intento $attempt/$maxAttempts '
    'target="$targetText" ${_scrollMetrics(candidate)} '
    'jump=${target.toStringAsFixed(1)}',
  );

  if ((target - before).abs() < 0.5) {
    // Puede cambiar el maxScrollExtent cuando un ListView perezoso construye
    // nuevos hijos; damos un pump y dejamos que el siguiente intento recalcule.
    await tester.pump(const Duration(milliseconds: 350));
    return false;
  }

  position.jumpTo(target);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
  return true;
}

Future<void> ensureTextVisible(
  WidgetTester tester,
  String text, {
  int maxDrags = 18,
  double dy = -420,
}) async {
  for (var attempt = 1; attempt <= maxDrags; attempt++) {
    if (_interactiveText(text).evaluate().isNotEmpty) {
      debugPrint(
        '[QA-V3.1.2][SCROLL] FOUND "$text" '
        '${_scrollMetrics(_primaryVerticalScroll(tester))}',
      );
      return;
    }

    await _programmaticScrollStep(
      tester,
      targetText: text,
      attempt: attempt,
      maxAttempts: maxDrags,
      dy: dy,
    );
  }

  if (_interactiveText(text).evaluate().isNotEmpty) {
    debugPrint(
      '[QA-V3.1.2][SCROLL] FOUND "$text" despues del ultimo salto '
      '${_scrollMetrics(_primaryVerticalScroll(tester))}',
    );
    return;
  }

  throw TestFailure(
    'No se pudo hacer visible: $text. '
    '${_scrollMetrics(_primaryVerticalScroll(tester))}',
  );
}

Future<void> tapTextAfterScroll(
  WidgetTester tester,
  String text, {
  int maxDrags = 18,
  double dy = -420,
}) async {
  await ensureTextVisible(
    tester,
    text,
    maxDrags: maxDrags,
    dy: dy,
  );
  final hit = _interactiveText(text);
  if (hit.evaluate().isEmpty) {
    throw TestFailure('El texto esta construido pero no es interactuable: $text');
  }
  await tester.tap(hit.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> openClientServiceDetail(
  WidgetTester tester, {
  required String marker,
  required int requestId,
}) async {
  await tapDestination(tester, 'Actividades', waitForText: 'Tus actividades');
  await tapTextAfterScroll(tester, marker, maxDrags: 20);
  await pumpUntil(tester, find.text('Solicitud #$requestId'));
  debugPrint('[QA-V3.1.2] Detalle de servicio $requestId abierto: $marker');
}

Future<void> openClientService(
  WidgetTester tester, {
  required String marker,
  required int requestId,
}) async {
  await openClientServiceDetail(tester, marker: marker, requestId: requestId);
  await ensureTextVisible(tester, 'SOS y escalamiento', maxDrags: 18);
  expect(find.text('SOS y escalamiento').hitTestable(), findsOneWidget);
  debugPrint('[QA-V3.1.2] Servicio $requestId listo para SOS: $marker');
}

Future<void> activateSosFromUi(
  WidgetTester tester, {
  required String reason,
}) async {
  await tapTextAfterScroll(tester, 'ACTIVAR SOS', maxDrags: 20);
  await pumpUntil(tester, find.text('Activar SOS'));
  final fields = find.byType(TextField);
  expect(fields, findsOneWidget);
  await tester.enterText(fields.first, reason);
  await tester.tap(find.text('Activar SOS ahora').hitTestable().first);
  await tester.pump(const Duration(milliseconds: 400));
}
