import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Builds the dark Material 3 theme. Mirrors the React/Tailwind side:
/// magenta + pink brand gradient over an ink-ladder dark surface, Jost for
/// text, Overpass Mono for monetary numbers.
ThemeData buildAppTheme() {
  // Jost as the default text theme; Overpass Mono is opt-in via [numTextStyle].
  final textTheme = GoogleFonts.jostTextTheme(
    ThemeData.dark().textTheme,
  ).apply(
    bodyColor: AppColors.ink100,
    displayColor: AppColors.ink100,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandPrimary,
    brightness: Brightness.dark,
    surface: AppColors.ink900,
    primary: AppColors.brandPrimary,
    secondary: AppColors.brandSecondary,
    error: AppColors.danger,
  ).copyWith(
    surfaceContainerHighest: AppColors.ink800,
    onSurface: AppColors.ink100,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.ink950,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink950,
      foregroundColor: AppColors.ink100,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ink950.withValues(alpha: 0.6),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.brandPrimary.withValues(alpha: 0.6),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.ink300),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink400),
    ),
    cardTheme: CardThemeData(
      color: AppColors.ink900.withValues(alpha: 0.7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink800,
      contentTextStyle: TextStyle(color: AppColors.ink100),
      behavior: SnackBarBehavior.floating,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.ink950,
      selectedItemColor: AppColors.brandAccent,
      unselectedItemColor: AppColors.ink400,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.white12,
      thickness: 1,
      space: 0,
    ),
  );
}

/// Text style for monetary / numeric values. Uses Overpass Mono with
/// tabular figures so columns of numbers line up visually.
TextStyle numTextStyle({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w400,
  Color color = AppColors.ink100,
}) {
  return GoogleFonts.overpassMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
