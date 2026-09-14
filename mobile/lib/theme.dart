import 'package:flutter/material.dart';

// design tokens. brand = warm-but-serious "ledger" identity: deep teal panels,
// mint for money/positive, gold for rank/best. numbers use space grotesk.
class AppColors {
  static const ink = Color(0xFF0B2E28);
  static const teal = Color(0xFF0E6B57);
  static const tealDark = Color(0xFF0B473A);
  static const mint = Color(0xFF2FD3A5);
  static const gold = Color(0xFFF2B33D);
  static const paper = Color(0xFFEDF2EF);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFDCE5E0);
  static const muted = Color(0xFF6B7C76);
}

const kRadius = 24.0;
const kRadiusSm = 16.0;

// space grotesk for figures/headlines; tabular-ish, financial character.
TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color, double spacing = -0.5}) =>
    TextStyle(fontFamily: 'SpaceGrotesk', fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.05);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    secondary: AppColors.mint,
    surface: AppColors.card,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.paper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5),
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: AppColors.line)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
        textStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
  );
}
