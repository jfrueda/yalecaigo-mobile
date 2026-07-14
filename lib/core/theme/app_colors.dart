import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1F5E73);
  static const primaryMedium = Color(0xFF2E7489);
  static const primaryDark = Color(0xFF173F4D);
  static const secondary = Color(0xFF4FA6A2);
  static const warmAccent = Color(0xFFE8B79C);

  static const background = Color(0xFFF7FAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFEEF4F4);
  static const selectionSoft = Color(0xFFDCEBE9);
  static const disabledSurface = Color(0xFFF0F4F5);
  static const border = Color(0xFFDCE6E7);
  static const textPrimary = Color(0xFF243237);
  static const textSecondary = Color(0xFF627279);
  static const disabledText = Color(0xFF93A2A7);

  static const success = Color(0xFF468B68);
  static const warning = Color(0xFFC38B32);
  static const danger = Color(0xFFC25757);
  static const information = Color(0xFF4D7896);

  static Color tint(Color color, [double opacity = 0.12]) {
    return color.withValues(alpha: opacity);
  }
}
