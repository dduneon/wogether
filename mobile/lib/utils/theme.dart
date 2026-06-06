import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

// ── 테마 무관 고정 색상 ───────────────────────────────────────────────
class WColors {
  static const cyan   = Color(0xFF22d3ee);
  static const pink   = Color(0xFFf472b6);
  static const green  = Color(0xFF4ade80);
  static const yellow = Color(0xFFfacc15);
  static const red    = Color(0xFFf87171);

  // ── 테마 의존 동적 색상 ─────────────────────────────────────────────
  static bool get _light => ThemeProvider().isLight;

  static Color get bg      => _light ? const Color(0xFFF5F5F7) : const Color(0xFF080808);
  static Color get bg2     => _light ? const Color(0xFFFFFFFF) : const Color(0xFF101010);
  static Color get bg3     => _light ? const Color(0xFFE8E8ED) : const Color(0xFF181818);
  static Color get border  => _light ? const Color(0x14000000) : const Color(0x12FFFFFF);
  static Color get borderH => _light ? const Color(0x28000000) : const Color(0x24FFFFFF);
  static Color get purple  => const Color(0xFFa855f7);
  static Color get purpleL => const Color(0xFFc084fc);
  static Color get text      => _light ? const Color(0xFF0A0A0A) : const Color(0xFFfafafa);
  static Color get textMuted => _light ? const Color(0xFF6B7280) : const Color(0xFF71717a);
  static Color get textDim   => _light ? const Color(0xFF9CA3AF) : const Color(0xFF3f3f46);

  static LinearGradient get gradientPurpleCyan => const LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFa855f7), Color(0xFF22d3ee)],
  );
  static LinearGradient get gradientPurplePink => const LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFa855f7), Color(0xFF7c3aed)],
  );
  static LinearGradient get gradientProgress => const LinearGradient(
    colors: [Color(0xFFa855f7), Color(0xFF22d3ee)],
  );
}

// ── 테마 빌더 ────────────────────────────────────────────────────────
ThemeData buildTheme() => buildDynamicTheme(ThemeProvider());

ThemeData buildDynamicTheme(ThemeProvider p) {
  final isLight = p.isLight;
  final bg2 = WColors.bg2;
  final bg3 = WColors.bg3;
  final accent = WColors.purple;
  final accentL = WColors.purpleL;
  final textColor   = WColors.text;
  final textMuted   = WColors.textMuted;
  final textDim     = WColors.textDim;
  final borderColor = WColors.border;
  final borderH     = WColors.borderH;

  final base = isLight ? ThemeData.light() : ThemeData.dark();
  final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
    bodyColor: textColor,
    displayColor: textColor,
  );

  return base.copyWith(
    scaffoldBackgroundColor: WColors.bg,
    colorScheme: (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      surface: bg2,
      primary: accent,
      secondary: WColors.cyan,
      error: WColors.red,
      onSurface: textColor,
      onPrimary: Colors.white,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: bg2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg3,
      labelStyle: TextStyle(color: textMuted, fontSize: 13),
      hintStyle: TextStyle(color: textDim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: borderH),
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentL,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
      ),
    ),
    dividerColor: borderColor,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bg3,
      contentTextStyle: GoogleFonts.spaceGrotesk(color: textColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
