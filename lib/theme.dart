import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0D0D1A);
  static const surface = Color(0xFF17172B);
  static const gold = Color(0xFFC9A84C);
  static const mutedGold = Color(0xFFA8925F);
  // Brighter than the standard accent gold -- reserved for cazimi, the
  // rarest and most traditionally significant hit condition.
  static const cazimiGold = Color(0xFFFFD700);
  static const bodyText = Color(0xFFE6E4EF);
  static const mutedText = Color(0xFF9C99AC);
  static const mutedWhite = Color(0xFFCCCCCC);
  static const warning = Color(0xFFCF6679);
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.bodyText, displayColor: AppColors.bodyText)
        .copyWith(
          headlineLarge: GoogleFonts.cormorantGaramond(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
            letterSpacing: 0.5,
          ),
          headlineMedium: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
          titleLarge: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.bodyText,
          ),
          titleMedium: GoogleFonts.cormorantGaramond(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        onPrimary: AppColors.background,
        onSurface: AppColors.bodyText,
        error: const Color(0xFFCF6679),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
          letterSpacing: 1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.mutedText),
        hintStyle: const TextStyle(color: AppColors.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.background),
        side: const BorderSide(color: Colors.white38),
      ),
      dividerColor: Colors.white24,
    );
  }
}
