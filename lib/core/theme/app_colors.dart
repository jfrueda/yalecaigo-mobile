import 'package:flutter/material.dart';

/// Identidad visual YaLeCaigo.
///
/// La paleta combina confianza (azul petróleo), cercanía (teal),
/// acompañamiento humano (coral) y energía positiva (dorado).
abstract final class AppColors {
  static const primary = Color(0xFF0E5A5A);
  static const primaryMedium = Color(0xFF087878);
  static const primaryDark = Color(0xFF073F43);
  static const secondary = Color(0xFF0FA5A0);
  static const coral = Color(0xFFF25645);
  static const gold = Color(0xFFF5B23D);

  // Alias conservado para no romper componentes existentes.
  static const warmAccent = coral;

  static const background = Color(0xFFF6FAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFEAF5F4);
  static const selectionSoft = Color(0xFFD7EFED);
  static const coralSoft = Color(0xFFFFE8E3);
  static const goldSoft = Color(0xFFFFF2D7);
  static const disabledSurface = Color(0xFFF0F4F4);
  static const border = Color(0xFFD5E4E3);

  static const textPrimary = Color(0xFF1F3033);
  static const textSecondary = Color(0xFF627377);
  static const disabledText = Color(0xFF92A2A5);

  static const success = Color(0xFF37966F);
  static const warning = Color(0xFFC88422);
  static const danger = Color(0xFFD64E45);
  static const information = Color(0xFF287D96);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, secondary],
  );

  static Color tint(Color color, [double opacity = 0.12]) {
    return color.withValues(alpha: opacity);
  }
}
