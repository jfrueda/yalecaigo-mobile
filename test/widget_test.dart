import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalecaigo/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('la pantalla de acceso muestra los controles principales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);
  });
}
