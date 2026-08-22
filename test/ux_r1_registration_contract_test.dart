import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/network/endpoints.dart';

void main() {
  group('UX-R1 - registro simplificado', () {
    test('expone geografía multipaís y cambio de modo', () {
      expect(Endpoints.geographyCountries, '/auth/geography/countries/');
      expect(Endpoints.geographyPlaces, '/auth/geography/places/');
      expect(Endpoints.modes, '/auth/modes/');
    });

    test('la entrada de registro usa una sola cuenta', () {
      final source = File(
        'lib/features/auth/presentation/role_selection_page.dart',
      ).readAsStringSync();
      expect(source, contains('Una cuenta para usar GoWith a tu manera'));
      expect(source, contains('Crear mi cuenta'));
      expect(source, isNot(contains("value: 'client'")));
      expect(source, isNot(contains("value: 'provider'")));
    });

    test('personas de confianza no muestran verificación de terceros', () {
      final source = File(
        'lib/features/account/presentation/emergency_contacts_page.dart',
      ).readAsStringSync();
      expect(source, contains('Personas de confianza'));
      expect(source, isNot(contains('Pendiente de verificación')));
      expect(source, isNot(contains('backend')));
    });

    test('la habilitación reutiliza la selfie como foto de perfil', () {
      final source = File(
        'lib/features/provider/presentation/provider_enablement_page.dart',
      ).readAsStringSync();
      expect(source, contains('use_selfie_as_profile_photo'));
    });

    test('sexo es obligatorio en registro normal y social', () {
      final register = File(
        'lib/features/auth/presentation/register_page.dart',
      ).readAsStringSync();
      final social = File(
        'lib/features/auth/presentation/social_complete_registration_page.dart',
      ).readAsStringSync();
      final auth = File(
        'lib/features/auth/data/auth_service.dart',
      ).readAsStringSync();
      expect(register, contains("labelText: 'Sexo'"));
      expect(register, contains("gender: _gender!"));
      expect(social, contains("labelText: 'Sexo'"));
      expect(social, contains("gender: _gender!"));
      expect(auth, contains("'gender': gender"));
    });

    test('muestra identidad verificada y un selector de modo legible', () {
      final account = File(
        'lib/features/account/presentation/account_overview_page.dart',
      ).readAsStringSync();
      final switcher = File(
        'lib/shared/widgets/mode_switch_button.dart',
      ).readAsStringSync();
      expect(account, contains('Identidad verificada'));
      expect(account, contains('Icons.verified_rounded'));
      expect(switcher, contains('Modo actual:'));
      expect(switcher, contains('Cambiar a'));
    });

    test('la interfaz de registro no expone mensajes de desarrollo', () {
      final files = [
        'lib/features/auth/presentation/register_page.dart',
        'lib/features/auth/presentation/onboarding_status_page.dart',
        'lib/features/provider/presentation/provider_enablement_page.dart',
      ];
      for (final path in files) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('django')));
        expect(source, isNot(contains('migración')));
        expect(source, isNot(contains('backend')));
      }
    });
  });
}
