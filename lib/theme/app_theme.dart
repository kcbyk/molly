import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF08080C);
  static const Color cardBg = Color(0xFF13131A);
  static const Color cardBorder = Color(0xFF1F1F2A);
  static const Color playerBg = Color(0xFF1A1A24);
  static const Color playerBorder = Color(0xFF262634);
  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textMuted = Color(0xFF9A9AA8);
  static const Color limeAccent = Color(0xFFB8F34B);
  static const Color heartPink = Color(0xFFFF6B8A);
  static const Color sheetHandle = Color(0xFF3A3A46);
  static const Color navBorder = Color(0xFF181822);
  static const Color activePillBg = Color(0x24FFFFFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.manrope().fontFamily,
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.dark().textTheme,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.limeAccent,
        surface: AppColors.cardBg,
      ),
    );
  }
}
