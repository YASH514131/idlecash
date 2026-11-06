import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pure OLED Dark Theme Colors from screenshot
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0B0D13);
  static const Color card = Color(0xFF12151E);
  static const Color cardBorder = Color(0xFF1E2330);
  static const Color cardBorderLight = Color(0xFF282F42);

  // Accent Colors
  static const Color accentGreen = Color(0xFF00E599);
  static const Color accentGreenDark = Color(0xFF0D3325);
  static const Color accentBlue = Color(0xFF0052FF);
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentRed = Color(0xFFFF453A);
  static const Color accentAmber = Color(0xFFFFB300);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E95A8);
  static const Color textTertiary = Color(0xFF555D73);

  // ─── Elite Font Pairing ───────────────────────────────────────────────────
  // Display & Titles: Outfit (Geometric, luxury, futuristic)
  static TextStyle displayStyle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w800,
    Color color = Colors.white,
    double letterSpacing = -0.5,
    double? height,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Numbers & Financial Figures: Space Grotesk (Sharp, high-tech, DeFi standard)
  static TextStyle numberStyle({
    double fontSize = 26,
    FontWeight fontWeight = FontWeight.w800,
    Color color = Colors.white,
    double letterSpacing = -0.6,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // Body & Subtitles: Plus Jakarta Sans (Ultra-clean, crisp legibility)
  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textSecondary,
    double height = 1.4,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // Button Styles
  static final ButtonStyle primaryPillButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
  );

  static final ButtonStyle secondaryPillButton = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: const BorderSide(color: cardBorderLight, width: 1.2),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: GoogleFonts.outfit(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );

  static ThemeData get themeData {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentBlue,
      canvasColor: surface,
      cardColor: card,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.0),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.8),
        headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.4),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.plusJakartaSans(color: Colors.white),
        bodyMedium: GoogleFonts.plusJakartaSans(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF08090C),
        selectedItemColor: Colors.white,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
