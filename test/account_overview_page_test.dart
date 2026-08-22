import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/features/account/presentation/account_overview_page.dart';

void main() {
  Widget buildPage(Map<String, dynamic> data) {
    return MaterialApp(
      home: Scaffold(
        body: AccountOverviewPage(
          profile: data,
          providerMode: true,
          onLogout: () {},
          onOpenProfile: () {},
          onOpenSecurityPhone: () {},
          onOpenIdentity: () {},
          onOpenOnboarding: () {},
          onOpenEmergencyContacts: () {},
          onOpenSessions: () {},
          onOpenAccountSecurity: () {},
          onOpenPreferences: () {},
          onOpenBlockedUsers: () {},
          onOpenAccountDeletion: () {},
          onOpenProviderCapabilities: () {},
        ),
      ),
    );
  }

  testWidgets('muestra nombre, correo y habilitación desde respuesta anidada', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage({
        'user': {
          'username': 'ana',
          'email': 'ana@example.com',
          'status': 'VERIFIED',
          'activation_eligible': true,
          'profile': {
            'first_name': 'Ana',
            'last_name': 'Prueba',
            'city': 'Bogotá',
          },
        },
        'onboarding': {
          'account': {'display_name': 'Ana Prueba'},
          'activation': {'eligible': true},
        },
      }),
    );

    expect(find.text('Ana Prueba'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Cuenta habilitada'), findsOneWidget);
  });

  testWidgets('no confunde estado VERIFIED con habilitación incompleta', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage({
        'display_name': 'Carlos Proveedor',
        'email': 'carlos@example.com',
        'status': 'VERIFIED',
        'activation_eligible': false,
        'profile': {'city': 'Tunja'},
        'onboarding': {
          'activation': {
            'eligible': false,
            'missing': ['identity_verified'],
          },
        },
      }),
    );

    expect(find.text('Carlos Proveedor'), findsOneWidget);
    expect(find.text('Pendiente de requisitos'), findsOneWidget);
    expect(find.text('Cuenta habilitada'), findsNothing);
  });
}
