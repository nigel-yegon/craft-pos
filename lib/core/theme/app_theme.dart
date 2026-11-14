import 'package:flutter/material.dart';


class AppTheme {
  static const double navClearance = 96.0;
  // ─── Palette ───
  static const Color inkBlack = Color(0xFF04151F);
  static const Color heroGreen = Color(0xFF0F3D2E);
  static const Color midGreen = Color(0xFF1E5C43);
  static const Color brightGreen = Color(0xFF3DDC84);
  static const Color softMint = Color(0xFFE8F7EE);
  static const Color burntOrange = Color(0xFFC44900);
  static const Color midnightViolet = Color(0xFF432534);

  // ─── Semantic ───
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceMuted = softMint;
  static const Color primary = brightGreen;
  static const Color accent = heroGreen;

  // ─── Text ───
  static const Color onLightPrimary = inkBlack;
  static const Color onLightSecondary = Color(0xFF4B5D55);
  static const Color onLightMuted = Color(0xFF8F9C96);

  static const Color onHeroPrimary = Colors.white;
  static const Color onHeroSecondary = Color(0xFFB7D3C3);
  static const Color onHeroMuted = Color(0xFF7E9E8C);

  // ─── Aliases ───
  static const Color onDarkPrimary = onHeroPrimary;
  static const Color onDarkSecondary = onHeroSecondary;
  static const Color onDarkMuted = onHeroMuted;

  static const Color textPrimary = onLightPrimary;
  static const Color textSecondary = onLightSecondary;
  static const Color textMuted = onLightMuted;

  static const Color warning = burntOrange;
  static const Color success = Color(0xFF1F8A4C);
  static const Color warningRed = warning;
  static const Color successGreen = success;

  static const Color forest = heroGreen;
  static const Color forestDeep = midGreen;
  static const Color forestMid = midGreen;
  static const Color deepForest = heroGreen;
  static const Color primaryGreen = brightGreen;
  static const Color accentMint = brightGreen;
  static const Color wheat = softMint;
  static const Color cardWhite = Colors.white;
  static const Color backgroundGrey = background;
  static const Color textDark = inkBlack;
  static const Color textLight = onLightSecondary;
  static const Color onForestPrimary = onHeroPrimary;
  static const Color onForestSecondary = onHeroSecondary;
  static const Color onForestMuted = onHeroMuted;

  // ─── Radii ───
  static const double radiusSmall = 12;
  static const double radiusMedium = 18;
  static const double radiusLarge = 24;
  static const double radiusPill = 999;
  static const double hairline = 0.5;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,

      // ⭐ Global Font Family
      fontFamily: 'Inter',

      colorScheme: ColorScheme.fromSeed(
        seedColor: brightGreen,
        primary: brightGreen,
        secondary: heroGreen,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: inkBlack),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      // ⭐ Apply Inter to all Text Themes
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 42,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          height: 1.05,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          color: onLightSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          color: onLightSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          color: onLightMuted,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          color: onLightMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(
            color: inkBlack.withValues(alpha: 0.06),
            width: hairline,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brightGreen,
          foregroundColor: inkBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: heroGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brightGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkBlack,
          side: BorderSide(
            color: inkBlack.withValues(alpha: 0.12),
            width: hairline,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softMint,
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: brightGreen),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          color: onLightMuted.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: onLightMuted,
          fontSize: 13,
        ),
        prefixIconColor: onLightMuted,
        suffixIconColor: onLightMuted,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brightGreen,
        foregroundColor: inkBlack,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: heroGreen,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(
            color: inkBlack.withValues(alpha: 0.06),
            width: hairline,
          ),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: inkBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: onLightSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: inkBlack.withValues(alpha: 0.06),
        thickness: hairline,
        space: 1,
      ),
    );
  }
}