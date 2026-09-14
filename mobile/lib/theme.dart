import 'package:flutter/material.dart';

enum AppThemeStyle { pocket, ledger }

class AppPalette extends ThemeExtension<AppPalette> {
  final Color ink;
  final Color teal;
  final Color tealDark;
  final Color mint;
  final Color gold;
  final Color paper;
  final Color card;
  final Color line;
  final Color muted;
  final bool outlined;

  const AppPalette({
    required this.ink,
    required this.teal,
    required this.tealDark,
    required this.mint,
    required this.gold,
    required this.paper,
    required this.card,
    required this.line,
    required this.muted,
    required this.outlined,
  });

  static const pocket = AppPalette(
    ink: Color(0xFF111111),
    teal: Color(0xFFD6BFFF),
    tealDark: Color(0xFFC8FF9F),
    mint: Color(0xFFBFF59A),
    gold: Color(0xFFFFD88A),
    paper: Color(0xFFF4F3F6),
    card: Color(0xFFFFFFFF),
    line: Color(0xFF151515),
    muted: Color(0xFF68656B),
    outlined: true,
  );

  static const ledger = AppPalette(
    ink: Color(0xFF0B2E28),
    teal: Color(0xFF0E6B57),
    tealDark: Color(0xFF0B473A),
    mint: Color(0xFF2FD3A5),
    gold: Color(0xFFF2B33D),
    paper: Color(0xFFEDF2EF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFDCE5E0),
    muted: Color(0xFF6B7C76),
    outlined: false,
  );

  @override
  AppPalette copyWith({Color? ink, Color? teal, Color? tealDark, Color? mint, Color? gold, Color? paper, Color? card, Color? line, Color? muted, bool? outlined}) {
    return AppPalette(
      ink: ink ?? this.ink,
      teal: teal ?? this.teal,
      tealDark: tealDark ?? this.tealDark,
      mint: mint ?? this.mint,
      gold: gold ?? this.gold,
      paper: paper ?? this.paper,
      card: card ?? this.card,
      line: line ?? this.line,
      muted: muted ?? this.muted,
      outlined: outlined ?? this.outlined,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other ?? this;
}

extension AppPaletteContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}

const kRadius = 24.0;
const kRadiusSm = 16.0;

TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color, double spacing = -0.5}) =>
    TextStyle(fontFamily: 'SpaceGrotesk', fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.05);

ThemeData buildTheme(AppThemeStyle style) {
  final colors = style == AppThemeStyle.pocket ? AppPalette.pocket : AppPalette.ledger;
  final outline = colors.outlined ? colors.line : const Color(0xFFDCE5E0);
  final scheme = ColorScheme.fromSeed(seedColor: colors.teal, primary: colors.teal, secondary: colors.mint, surface: colors.card, brightness: Brightness.light);
  return ThemeData(
    colorScheme: scheme,
    extensions: [colors],
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: colors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.paper,
      foregroundColor: colors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.w700, color: colors.ink, letterSpacing: -0.5),
    ),
    textTheme: TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w700, color: colors.ink), bodyMedium: TextStyle(color: colors.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: BorderSide(color: outline, width: colors.outlined ? 1.5 : 1)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: BorderSide(color: outline, width: colors.outlined ? 1.5 : 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: BorderSide(color: colors.ink, width: 2)),
      labelStyle: TextStyle(color: colors.muted),
      floatingLabelStyle: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.outlined ? colors.ink : colors.teal,
        foregroundColor: colors.outlined ? Colors.white : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
        textStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
  );
}
