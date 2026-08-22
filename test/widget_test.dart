import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('La pantalla de acceso muestra los métodos disponibles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('GoWith'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Facebook'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Crear cuenta'), findsOneWidget);
  });
}
