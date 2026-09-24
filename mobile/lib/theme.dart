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
  // each colour has one job. teal used to be both the hero's fill and the colour of every
  // spinner, icon and "disetujui" label, which cannot work: a fill wants to be pale, text wants
  // to be dark. on pocket that left all of that text lavender on white. wash is the fill now
  final Color wash;
  final Color pending;
  final Color danger;
  // hairline between rows. on pocket `line` is solid ink, right for a card's edge and far too
  // heavy for a divider inside one
  final Color rule;
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
    required this.wash,
    required this.pending,
    required this.danger,
    required this.rule,
    required this.outlined,
  });

  // pocket ledger keeps its identity (pastel, ink outlines, a bit playful) with the pastels now
  // one family: all three sit at the same oklch lightness and chroma (0.88 / 0.085). the old lime
  // ran at 44% more chroma than the lavender beside it, which is why it looked neon. every pairing
  // below was measured against wcag: text is at least 4.5:1 on each surface it lands on
  static const pocket = AppPalette(
    ink: Color(0xFF1F1B16),
    teal: Color(0xFF27694A),
    tealDark: Color(0xFF194E35),
    mint: Color(0xFFB0E8BA),
    gold: Color(0xFFF3D598),
    paper: Color(0xFFF5F0E4),
    card: Color(0xFFFFFCF7),
    line: Color(0xFF1F1B16),
    muted: Color(0xFF5F574B),
    wash: Color(0xFFDCC8FF),
    pending: Color(0xFF915006),
    danger: Color(0xFFB6322D),
    rule: Color(0x2E1F1B16),
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
    wash: Color(0xFFD8EEE6),
    pending: Color(0xFF915006),
    danger: Color(0xFFB6322D),
    rule: Color(0xFFDCE5E0),
    outlined: false,
  );

  @override
  AppPalette copyWith(
      {Color? ink,
      Color? teal,
      Color? tealDark,
      Color? mint,
      Color? gold,
      Color? paper,
      Color? card,
      Color? line,
      Color? muted,
      Color? wash,
      Color? pending,
      Color? danger,
      Color? rule,
      bool? outlined}) {
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
      wash: wash ?? this.wash,
      pending: pending ?? this.pending,
      danger: danger ?? this.danger,
      rule: rule ?? this.rule,
      outlined: outlined ?? this.outlined,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other ?? this;
}

extension AppPaletteContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
  bool get usesLargeText => MediaQuery.textScalerOf(this).scale(16) >= 20;
  double get pageInset => MediaQuery.sizeOf(this).width < 380 ? 16 : 20;
}

const kRadius = 24.0;
const kRadiusSm = 16.0;

EdgeInsets pagePadding(BuildContext context,
        {double top = 12, double bottom = 32}) =>
    EdgeInsets.fromLTRB(context.pageInset, top, context.pageInset, bottom);

// tracking has to scale with size: -0.5 flatters a 42px total and cramps an 11px axis label into
// a smudge, which is why the small type read as broken. an explicit spacing still wins
double _tracking(double size) {
  if (size >= 28) return -1.0;
  if (size >= 20) return -0.4;
  if (size >= 15) return 0;
  return 0.2;
}

TextStyle display(double size,
        {FontWeight weight = FontWeight.w700,
        Color? color,
        double? spacing}) =>
    TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing ?? _tracking(size),
        // every rupiah figure is display type, and in a ledger the digits have to line up down a
        // column, so fix the digit width rather than letting 1 be narrower than 8
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.18);

ThemeData buildTheme(AppThemeStyle style) {
  final colors =
      style == AppThemeStyle.pocket ? AppPalette.pocket : AppPalette.ledger;
  final outline = colors.outlined ? colors.line : const Color(0xFFDCE5E0);
  final edge = BorderSide(color: colors.line, width: colors.outlined ? 1.5 : 1);
  // primary used to be the hero's pastel fill, so every material control painting white on
  // primary (switches, progress, selected chips) sat at 1.65:1 on pocket and all but vanished
  final scheme = ColorScheme.fromSeed(
      seedColor: colors.teal,
      primary: colors.teal,
      onPrimary: Colors.white,
      secondary: colors.mint,
      onSecondary: colors.ink,
      error: colors.danger,
      onError: Colors.white,
      surface: colors.card,
      onSurface: colors.ink,
      brightness: Brightness.light);
  return ThemeData(
    colorScheme: scheme,
    extensions: [colors],
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
      },
    ),
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: colors.paper,
    // a spinner that names no colour now gets the accent instead of material's seed guess
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.teal, linearTrackColor: colors.rule),
    dividerTheme: DividerThemeData(color: colors.rule, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.ink,
      contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: colors.card,
          fontSize: 14,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: colors.outlined ? 0 : 4,
      highlightElevation: colors.outlined ? 0 : 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
          side: colors.outlined ? edge : BorderSide.none),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.card,
      selectedColor: colors.mint,
      side: colors.outlined ? edge : BorderSide(color: colors.line),
      labelStyle: TextStyle(
          fontFamily: 'Manrope', color: colors.ink, fontWeight: FontWeight.w600),
      checkmarkColor: colors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
          side: colors.outlined ? edge : BorderSide.none),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: colors.outlined ? edge : BorderSide.none),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.paper,
      foregroundColor: colors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colors.ink,
          letterSpacing: -0.5),
    ),
    textTheme: TextTheme(
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: colors.ink),
        bodyMedium: TextStyle(color: colors.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
          borderSide:
              BorderSide(color: outline, width: colors.outlined ? 1.5 : 1)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
          borderSide:
              BorderSide(color: outline, width: colors.outlined ? 1.5 : 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
          borderSide: BorderSide(color: colors.ink, width: 2)),
      labelStyle: TextStyle(color: colors.muted),
      floatingLabelStyle:
          TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.outlined ? colors.ink : colors.teal,
        foregroundColor: colors.outlined ? Colors.white : Colors.white,
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusSm)),
        textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusSm)),
      ),
    ),
  );
}

// fade + gentle rise used for every pushed route, on all platforms.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
