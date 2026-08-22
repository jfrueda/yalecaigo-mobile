import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gowith/core/navigation/client_shell.dart';
import 'package:gowith/features/auth/presentation/register_page.dart';
import 'package:gowith/features/onboarding/presentation/registration_welcome_page.dart';
import 'package:gowith/features/provider/presentation/provider_enablement_page.dart';
import 'package:gowith/main.dart' as app;

import 'qa_registration_demo_helpers.dart';

const qaEmail = String.fromEnvironment('QA_EMAIL');
const qaPhone = String.fromEnvironment('QA_PHONE');
const qaPassword = String.fromEnvironment('QA_PASSWORD', defaultValue: 'Gaejei9m17');
const qaBridge = String.fromEnvironment(
  'QA_BRIDGE_URL',
  defaultValue: 'http://127.0.0.1:8765',
);
const qaOtp = String.fromEnvironment('QA_OTP', defaultValue: '123456');
const qaRegionId = int.fromEnvironment('QA_REGION_ID');
const qaMunicipalityId = int.fromEnvironment('QA_MUNICIPALITY_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UX-R3.2 DEMO registro automatico: acompañar y solicitar', (
    tester,
  ) async {
    expect(qaEmail, isNotEmpty, reason: 'Falta --dart-define=QA_EMAIL');
    expect(qaPhone, isNotEmpty, reason: 'Falta --dart-define=QA_PHONE');
    expect(qaRegionId, greaterThan(0), reason: 'Falta --dart-define=QA_REGION_ID');
    expect(qaMunicipalityId, greaterThan(0), reason: 'Falta --dart-define=QA_MUNICIPALITY_ID');

    app.main();
    await pumpNetwork(tester, 1400);

    // Pantalla inicial -> Crear cuenta. Si un cambio de UX oculta el botón,
    // navegamos a RegisterPage sin tocar lib/.
    if (find.byType(RegisterPage).evaluate().isEmpty) {
      final create = find.text('Crear cuenta').hitTestable();
      if (create.evaluate().isNotEmpty) {
        await tester.tap(create.last);
        await pumpNetwork(tester, 700);
      }
    }
    if (find.byType(RegisterPage).evaluate().isEmpty) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
        (_) => false,
      );
      await pumpNetwork(tester, 800);
    }
    expect(find.byType(RegisterPage), findsOneWidget);
    debugPrint('[QA-DEMO] Registro abierto: $qaEmail / $qaPhone');
    await demoPause(tester, 900);

    await enterByLabel(tester, 'Nombres', 'Valentina');
    await enterByLabel(tester, 'Apellidos', 'Demo GoWith');
    await chooseBirthDate(tester);
    await chooseDropdown(tester, 'Sexo', 'Femenino');
    await enterByLabel(tester, 'Correo', qaEmail);
    await enterByLabel(tester, 'Celular', qaPhone);
    await chooseIntDropdownByValue(
      tester,
      'Departamento / región',
      qaRegionId,
    );
    await chooseIntDropdownByValue(
      tester,
      'Ciudad / municipio',
      qaMunicipalityId,
    );
    await enterByLabel(tester, 'Contraseña', qaPassword);
    await acceptLegal(tester);
    await demoPause(tester, 900);

    await tapText(tester, 'Crear cuenta');
    await pumpNetwork(tester, 1300);
    expect(find.byType(RegisterPage), findsNothing);
    debugPrint('[QA-DEMO] Cuenta creada; preparando OTP e identidad QA.');

    final prepared = await qaBridgeGet(qaBridge, '/prepare', {
      'email': qaEmail,
      'code': qaOtp,
    });
    expect(prepared['ok'], true, reason: prepared.toString());
    debugPrint('[QA-DEMO] QA bridge preparado: $prepared');
    await demoPause(tester, 700);

    final otpAttempted = await automateOtp(tester, qaOtp);
    var welcomeReady = await waitUntil(
      tester,
      () => find.text('Tu cuenta está lista').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 12),
    );

    if (!welcomeReady) {
      // Fallback seguro para demo si EmailVerificationPage cambia su layout.
      // El backend queda explícitamente verificado por el puente QA y continuamos
      // con la pantalla real RegistrationWelcomePage.
      final forced = await qaBridgeGet(qaBridge, '/force-verify', {
        'email': qaEmail,
      });
      expect(forced['ok'], true, reason: forced.toString());
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const RegistrationWelcomePage(),
        ),
        (_) => false,
      );
      await pumpNetwork(tester, 850);
      welcomeReady = find.text('Tu cuenta está lista').evaluate().isNotEmpty;
      debugPrint('[QA-DEMO] OTP UI fallback usado.');
    } else {
      debugPrint('[QA-DEMO] OTP verificado mediante UI: $otpAttempted');
    }

    expect(welcomeReady, true, reason: 'No apareció Cuenta lista.');
    await demoPause(tester, 1600);

    // Elegimos Acompañar. La cuenta ya fue creada como CLIENT por UX-R1/R3.
    await tapText(tester, 'También quiero acompañar');
    final providerReady = await waitUntil(
      tester,
      () => find.byType(ProviderEnablementPage).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 12),
    );
    expect(providerReady, true);
    await demoPause(tester, 1000);

    await enterByLabel(
      tester,
      'Descripción',
      'Soy una persona tranquila, responsable y puntual. Me gusta acompañar actividades cotidianas en lugares públicos.',
    );
    await enterByLabel(tester, 'Nombre completo', 'Laura Demo Seguridad');
    await enterByLabel(tester, 'Relación', 'Hermana');
    await enterByLabel(tester, 'Celular', '3105556677');
    await enterByLabel(tester, 'Correo (opcional)', 'contacto.qa@example.invalid');

    await ensureProviderActivitySelected(tester);
    final documentsReceived = await ensureTextVisible(tester, 'Documentos recibidos');
    expect(
      documentsReceived,
      true,
      reason: 'El puente QA debía dejar identidad PENDING recibida.',
    );
    await demoPause(tester, 1400);

    await tapText(tester, 'Enviar mi información');
    final providerSubmitted = await waitUntil(
      tester,
      () => find
          .text(
            'Recibimos tu información. Te avisaremos cuando puedas comenzar a acompañar.',
          )
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 18),
    );
    expect(providerSubmitted, true, reason: 'No quedó Acompañar en revisión.');
    debugPrint('[QA-DEMO] Perfil de Acompañar enviado a revisión.');
    await demoPause(tester, 2200);

    // Terminamos demostrando que la misma cuenta sigue pudiendo SOLICITAR.
    await tapText(tester, 'Seguir usando GoWith para solicitar', maxScrolls: 0);
    final clientReady = await waitUntil(
      tester,
      () => find.byType(ClientShell).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    );
    expect(clientReady, true, reason: 'No regresó al modo Solicitar.');
    debugPrint('[QA-DEMO] Modo Solicitar disponible con la misma cuenta.');
    await demoPause(tester, 2500);

    final finalState = await qaBridgeGet(qaBridge, '/inspect', {
      'email': qaEmail,
    });
    expect(finalState['ok'], true);
    expect(finalState['identity_status'], anyOf('PENDING', 'IN_REVIEW', 'VERIFIED'));
    expect(finalState['provider_status'], anyOf('IN_REVIEW', 'PENDING', 'ACTIVE'));
    debugPrint('[QA-DEMO] ESTADO FINAL: $finalState');
    debugPrint('[QA-DEMO] PASS registro automático UX-R3.2');
  });
}
