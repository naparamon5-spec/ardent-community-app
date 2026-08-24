import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ardent_colors.dart';

/// Builds the Ardent Networks [ThemeData] for the mobile app, mirroring the
/// web design system: Montserrat type, the red primary / navy ink palette,
/// and the shared radii and surface tokens.
class ArdentTheme {
  ArdentTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ArdentColors.accent,
      onPrimary: ArdentColors.fgOnDark,
      primaryContainer: ArdentColors.red100,
      onPrimaryContainer: ArdentColors.red900,
      secondary: ArdentColors.crimson500,
      onSecondary: ArdentColors.fgOnDark,
      secondaryContainer: ArdentColors.crimson100,
      onSecondaryContainer: ArdentColors.crimson700,
      tertiary: ArdentColors.navy600,
      onTertiary: ArdentColors.fgOnDark,
      tertiaryContainer: ArdentColors.statusOpenBg,
      onTertiaryContainer: ArdentColors.navy900,
      error: ArdentColors.statusUrgent,
      onError: ArdentColors.fgOnDark,
      errorContainer: ArdentColors.statusUrgentBg,
      onErrorContainer: ArdentColors.red900,
      surface: ArdentColors.bgSurface,
      onSurface: ArdentColors.fg1,
      surfaceContainerLowest: ArdentColors.bgSurface,
      surfaceContainerLow: ArdentColors.gray25,
      surfaceContainer: ArdentColors.bgApp,
      surfaceContainerHigh: ArdentColors.bgSubtle,
      surfaceContainerHighest: ArdentColors.gray200,
      onSurfaceVariant: ArdentColors.fg2,
      outline: ArdentColors.borderStrong,
      outlineVariant: ArdentColors.border,
      inverseSurface: ArdentColors.navy900,
      onInverseSurface: ArdentColors.fgOnDark,
      inversePrimary: ArdentColors.red300,
      shadow: ArdentColors.navy900,
      scrim: ArdentColors.navy900,
      surfaceTint: ArdentColors.accent,
    );

    final baseTextTheme = _textTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ArdentColors.bgApp,
      textTheme: baseTextTheme,
      primaryTextTheme: baseTextTheme,
      fontFamily: GoogleFonts.montserrat().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: ArdentColors.bgSurface,
        foregroundColor: ArdentColors.fg1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 17,
          height: 1.2,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w700,
          color: ArdentColors.fg1,
        ),
      ),
      cardTheme: CardThemeData(
        color: ArdentColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          side: const BorderSide(color: ArdentColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ArdentColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ArdentColors.bgSubtle,
        side: const BorderSide(color: ArdentColors.border),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ArdentColors.fg2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ArdentColors.accent,
          foregroundColor: ArdentColors.fgOnDark,
          disabledBackgroundColor: ArdentColors.gray200,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: ArdentSpacing.s5,
            vertical: ArdentSpacing.s3,
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ArdentRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ArdentColors.fg1,
          side: const BorderSide(color: ArdentColors.borderStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: ArdentSpacing.s5,
            vertical: ArdentSpacing.s3,
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ArdentRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ArdentColors.accent,
          textStyle: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ArdentColors.accent,
        foregroundColor: ArdentColors.fgOnDark,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ArdentColors.bgSurface,
        hintStyle: GoogleFonts.montserrat(color: ArdentColors.fg3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ArdentSpacing.s4,
          vertical: ArdentSpacing.s3,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          borderSide: const BorderSide(color: ArdentColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          borderSide: const BorderSide(color: ArdentColors.accent, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ArdentColors.bgSurface,
        selectedItemColor: ArdentColors.accent,
        unselectedItemColor: ArdentColors.fg3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ArdentColors.navy800,
        contentTextStyle: GoogleFonts.montserrat(color: ArdentColors.fgOnDark),
        actionTextColor: ArdentColors.red300,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArdentRadii.md),
        ),
      ),
    );
  }

  /// Montserrat type scale. Derived from the web `--text-*` tokens but scaled
  /// down for phones — the web values are desktop-sized and read as oversized
  /// on a handset. Hierarchy and proportions are preserved.
  static TextTheme _textTheme(TextTheme base) {
    return GoogleFonts.montserratTextTheme(base).copyWith(
      // display (web 44)
      displayLarge: GoogleFonts.montserrat(
        fontSize: 32,
        height: 1.08,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w800,
        color: ArdentColors.fg1,
      ),
      // h1 (web 32)
      headlineLarge: GoogleFonts.montserrat(
        fontSize: 24,
        height: 1.15,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
        color: ArdentColors.fg1,
      ),
      // h2 (web 24)
      headlineMedium: GoogleFonts.montserrat(
        fontSize: 20,
        height: 1.2,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
        color: ArdentColors.fg1,
      ),
      // h3 (web 19)
      titleLarge: GoogleFonts.montserrat(
        fontSize: 17,
        height: 1.25,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w700,
        color: ArdentColors.fg1,
      ),
      // lg (web 17)
      titleMedium: GoogleFonts.montserrat(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ArdentColors.fg1,
      ),
      // base (web 15)
      bodyLarge: GoogleFonts.montserrat(
        fontSize: 14,
        height: 1.45,
        color: ArdentColors.fg2,
      ),
      // sm (web 13)
      bodyMedium: GoogleFonts.montserrat(
        fontSize: 12.5,
        height: 1.4,
        color: ArdentColors.fg2,
      ),
      // xs (web 12)
      bodySmall: GoogleFonts.montserrat(
        fontSize: 11.5,
        height: 1.3,
        color: ArdentColors.fg3,
      ),
      // overline (web 11)
      labelSmall: GoogleFonts.montserrat(
        fontSize: 10.5,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: ArdentColors.fg3,
      ),
    );
  }
}
