import 'package:flutter/material.dart';

/// Design tokens — single source of truth. Mirror the React side so we keep
/// brand consistency across platforms.
abstract final class AppColors {
  // Brand gradient stops
  static const brandPrimary   = Color(0xFF0165FF); // cobalt blue
  static const brandSecondary = Color(0xFF00B4FF); // cyan
  static const brandAccent    = Color(0xFF77E7FF); // aqua

  // Surface ladder — darkest = ink950, lightest = ink100
  static const ink950 = Color(0xFF060B13);
  static const ink900 = Color(0xFF0C1323);
  static const ink800 = Color(0xFF17213A);
  static const ink700 = Color(0xFF273556);
  static const ink600 = Color(0xFF40557C);
  static const ink500 = Color(0xFF617AA4);
  static const ink400 = Color(0xFF8EAACD);
  static const ink300 = Color(0xFFB7D0EC);
  static const ink200 = Color(0xFFDCE7F8);
  static const ink100 = Color(0xFFF4F8FF);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger  = Color(0xFFDC2626);

  // The signature gradient — used on primary buttons, balance numbers, etc.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [brandPrimary, brandSecondary, brandAccent],
    stops: [0.0, 0.6, 1.0],
  );
}
