import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/preferences/app_preferences_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guarda y recupera las preferencias de accesibilidad', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = AppPreferencesController();

    await controller.update(
      textScale: 1.2,
      highContrast: true,
      reduceMotion: true,
    );

    final restored = AppPreferencesController();
    await restored.load();

    expect(restored.textScale, 1.2);
    expect(restored.highContrast, isTrue);
    expect(restored.reduceMotion, isTrue);
  });

  test('restablece las preferencias de accesibilidad', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = AppPreferencesController();
    await controller.update(
      textScale: 1.3,
      highContrast: true,
      reduceMotion: true,
    );

    await controller.resetAccessibility();

    expect(controller.textScale, 1.0);
    expect(controller.highContrast, isFalse);
    expect(controller.reduceMotion, isFalse);
  });
}
