import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _textScaleKey = 'gowith.accessibility.text_scale';
  static const String _highContrastKey = 'gowith.accessibility.high_contrast';
  static const String _reduceMotionKey = 'gowith.accessibility.reduce_motion';

  final FlutterSecureStorage _storage;

  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;

  Future<void> load() async {
    final values = await Future.wait<String?>([
      _storage.read(key: _textScaleKey),
      _storage.read(key: _highContrastKey),
      _storage.read(key: _reduceMotionKey),
    ]);

    final parsedScale = double.tryParse(values[0] ?? '');
    if (parsedScale != null && parsedScale >= 0.9 && parsedScale <= 1.35) {
      _textScale = parsedScale;
    }
    _highContrast = values[1] == 'true';
    _reduceMotion = values[2] == 'true';
  }

  Future<void> update({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
  }) async {
    if (textScale != null) {
      _textScale = textScale.clamp(0.9, 1.35).toDouble();
      await _storage.write(key: _textScaleKey, value: '$_textScale');
    }
    if (highContrast != null) {
      _highContrast = highContrast;
      await _storage.write(key: _highContrastKey, value: '$highContrast');
    }
    if (reduceMotion != null) {
      _reduceMotion = reduceMotion;
      await _storage.write(key: _reduceMotionKey, value: '$reduceMotion');
    }
    notifyListeners();
  }

  Future<void> resetAccessibility() async {
    _textScale = 1.0;
    _highContrast = false;
    _reduceMotion = false;
    await Future.wait<void>([
      _storage.delete(key: _textScaleKey),
      _storage.delete(key: _highContrastKey),
      _storage.delete(key: _reduceMotionKey),
    ]);
    notifyListeners();
  }
}

final AppPreferencesController appPreferences = AppPreferencesController();
