import 'package:flutter/material.dart';

/// Identidad visual de GoWith.
///
/// La paleta combina confianza, cercanía, energía y una lectura clara en
/// pantallas móviles. Se mantiene una única fuente de color para evitar
/// diferencias entre autenticación, navegación y operación.
abstract final class AppColors {
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryMedium = Color(0xFF16877D);
  static const Color primaryDark = Color(0xFF075E58);
  static const Color secondary = Color(0xFF2A9D8F);
  static const Color coral = Color(0xFFE85D4A);
  static const Color amber = Color(0xFFF4B740);
  static const Color gold = amber;

  // Alias usados por componentes heredados.
  static const Color teal = primary;
  static const Color tealDark = primaryDark;
  static const Color warmAccent = coral;

  static const Color background = Color(0xFFF6FAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEAF5F3);
  static const Color selectionSoft = Color(0xFFD7EFEC);
  static const Color coralSoft = Color(0xFFFFE8E3);
  static const Color goldSoft = Color(0xFFFFF2D7);
  static const Color disabledSurface = Color(0xFFF0F4F3);
  static const Color border = Color(0xFFD4E5E2);

  static const Color textPrimary = Color(0xFF16302D);
  static const Color textSecondary = Color(0xFF627773);
  static const Color disabledText = Color(0xFF92A5A1);
  static const Color ink = textPrimary;

  static const Color success = Color(0xFF37966F);
  static const Color warning = Color(0xFFC88422);
  static const Color danger = Color(0xFFD64E45);
  static const Color information = Color(0xFF287D96);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, secondary],
  );

  static Color tint(Color color, [double opacity = 0.12]) {
    return color.withValues(alpha: opacity);
  }
}
