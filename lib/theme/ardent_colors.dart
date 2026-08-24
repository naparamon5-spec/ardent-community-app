import 'package:flutter/material.dart';

/// Ardent Networks brand palette — ported from the web design system
/// (`app/assets/css/tokens.css`). Values are 1:1 with the CSS custom
/// properties so the mobile app reads as the same brand as the web app.
class ArdentColors {
  ArdentColors._();

  // ---- 1. Raw brand palette ----
  static const Color brandWhite = Color(0xFFFFFFFF);
  static const Color brandCrimson = Color(0xFFC6324C);
  static const Color brandCoral = Color(0xFFFF5969);
  static const Color brandNavy = Color(0xFF133341);
  static const Color brandRed = Color(0xFFE90408);
  static const Color brandGray = Color(0xFFD7D7D7);

  // ---- 2. Red scale (primary, anchored on #E90408) ----
  static const Color red50 = Color(0xFFFFF1F1);
  static const Color red100 = Color(0xFFFFDDDE);
  static const Color red200 = Color(0xFFFFB3B5);
  static const Color red300 = Color(0xFFFF8285);
  static const Color red400 = Color(0xFFFF5969);
  static const Color red500 = Color(0xFFE90408);
  static const Color red600 = Color(0xFFCC0306);
  static const Color red700 = Color(0xFFA30205);
  static const Color red800 = Color(0xFF7A0203);
  static const Color red900 = Color(0xFF520102);

  // ---- 3. Crimson scale (secondary) ----
  static const Color crimson100 = Color(0xFFF8DDE2);
  static const Color crimson300 = Color(0xFFE48295);
  static const Color crimson500 = Color(0xFFC6324C);
  static const Color crimson700 = Color(0xFF8E2237);

  // ---- 4. Navy / ink scale ----
  static const Color navy900 = Color(0xFF0B1E27);
  static const Color navy800 = Color(0xFF133341);
  static const Color navy700 = Color(0xFF1D4456);
  static const Color navy600 = Color(0xFF2C5A6E);
  static const Color navy500 = Color(0xFF43798F);
  static const Color navy400 = Color(0xFF6E9DAF);

  // ---- 5. Neutral / gray scale ----
  static const Color gray25 = Color(0xFFFCFCFD);
  static const Color gray50 = Color(0xFFF6F7F8);
  static const Color gray100 = Color(0xFFEDEEF0);
  static const Color gray200 = Color(0xFFE1E2E5);
  static const Color gray300 = Color(0xFFD7D7D7);
  static const Color gray400 = Color(0xFFB6B7BB);
  static const Color gray500 = Color(0xFF8C8E94);
  static const Color gray600 = Color(0xFF686A70);
  static const Color gray700 = Color(0xFF4A4C52);
  static const Color gray800 = Color(0xFF2E3035);
  static const Color gray900 = Color(0xFF16181C);

  // ---- 6. Status colors ----
  static const Color statusUrgent = Color(0xFFE90408);
  static const Color statusUrgentBg = Color(0xFFFFF1F1);
  static const Color statusHigh = Color(0xFFFF5969);
  static const Color statusHighBg = Color(0xFFFFECEE);
  static const Color statusOpen = Color(0xFF2C5A6E);
  static const Color statusOpenBg = Color(0xFFE8F0F3);
  // oklch(...) values converted to their sRGB hex equivalents.
  static const Color statusPending = Color(0xFFD9A227);
  static const Color statusPendingBg = Color(0xFFFAF1DE);
  static const Color statusResolved = Color(0xFF1FA37A);
  static const Color statusResolvedBg = Color(0xFFE3F5EE);

  // ---- 7. Semantic surface / text / border tokens ----
  static const Color bgApp = gray50;
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSubtle = gray100;
  static const Color bgInset = gray50;
  static const Color bgDark = navy800;
  static const Color bgDarkDeep = navy900;

  static const Color fg1 = navy900;
  static const Color fg2 = gray700;
  static const Color fg3 = gray500;
  static const Color fgOnDark = Color(0xFFFFFFFF);
  static const Color fgOnDark2 = Color(0xA8FFFFFF); // rgba(255,255,255,0.66)
  static const Color fgOnDark3 = Color(0x66FFFFFF); // rgba(255,255,255,0.40)

  static const Color border = gray200;
  static const Color borderStrong = gray300;
  static const Color borderDark = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)

  static const Color accent = red500;
  static const Color accentHover = red600;
  static const Color accentPress = red700;
  static const Color accentSoft = red50;
}

/// Corner radii, matching the web `--radius-*` tokens.
class ArdentRadii {
  ArdentRadii._();
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}

/// Spacing scale, matching the web `--space-*` tokens (4px base).
class ArdentSpacing {
  ArdentSpacing._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}
