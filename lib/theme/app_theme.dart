import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors using Tailwind colors
  static Color primaryColor = TWColors.slate.shade900;
  static Color secondaryColor = TWColors.emerald.shade500;
  static Color accentColor = TWColors.amber.shade500;
  static Color errorColor = TWColors.red.shade500;
  static Color warningColor = TWColors.yellow.shade500;
  static Color successColor = TWColors.emerald.shade500;

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        bodyLarge: GoogleFonts.poppins(fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.poppins(fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.poppins(fontWeight: FontWeight.w400),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryColor.withOpacity(0.2),
        circularTrackColor: primaryColor.withOpacity(0.15),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
