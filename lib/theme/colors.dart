import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // --- Brand Colors ---
  static const brandPrimary = Color(0xFF009688);
  static const brandSecondary = Color(0xFF00BFA5);
  static const brandAccent = Color(0xFF80CBC4);

  // --- Ink Ladder (Surfaces & Text) ---
  static const ink950 = Color(0xFF0B1214);
  static const ink900 = Color(0xFF111D20);
  static const ink800 = Color(0xFF1A2A2E);
  static const ink700 = Color(0xFF263B40);
  static const ink600 = Color(0xFF3B555B);
  static const ink500 = Color(0xFF5A787F);
  static const ink400 = Color(0xFF819EA5);
  static const ink300 = Color(0xFFABC3C8);
  static const ink200 = Color(0xFFD3E2E5);
  static const ink100 = Color(0xFFF0F6F7);

  // --- Status Variants (Dark UI System) ---

  // 🟢 Success (Emerald)
  static const success = Color(0xFF34D399); // الأيقونات / النقاط
  static const successBg = Color(0xFF064E3B); // الخلفية المكتومة
  static const successBorder = Color(0xFF065F46); // الحواف المتناسقة
  static const successText = Color(0xFFA7F3D0); // النص الواضح

  // 🟡 Warning (Amber)
  static const warning = Color(0xFFFBBF24);
  static const warningBg = Color(0xFF451A03);
  static const warningBorder = Color(0xFF78350F);
  static const warningText = Color(0xFFFEF3C7);

  // 🔴 Danger (Coral/Crimson)
  static const danger = Color(0xFFF87171);
  static const dangerBg = Color(0xFF4A0404);
  static const dangerBorder = Color(0xFF7F1D1D);
  static const dangerText = Color(0xFFFEE2E2);

  // 🔵 Info (Sky Blue)
  static const info = Color(0xFF60A5FA);
  static const infoBg = Color(0xFF1E3A8A);
  static const infoBorder = Color(0xFF1E40AF);
  static const infoText = Color(0xFFDBEAFE);

  // ⚪ Neutral (Slate) - مضافة للـ StatusPill الافتراضي
  static const neutral = Color(0xFF94A3B8);
  static const neutralBg = Color(0xFF1E293B);
  static const neutralBorder = Color(0xFF334155);
  static const neutralText = Color(0xFFF1F5F9);

  // --- Gradients ---
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandSecondary, brandAccent],
    stops: [0.0, 0.5, 1.0],
  );
}
