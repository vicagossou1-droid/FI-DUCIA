import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FiduciaColors {
  FiduciaColors._();

  static const Color navy = Color(0xFF0C2248);
  static const Color navyDeep = Color(0xFF07152F);
  static const Color green = Color(0xFF2FB92D);
  static const Color lime = Color(0xFFC4F11A);
  static const Color surfaceLight = Color(0xFFF4F7FB);
  static const Color surfaceDark = Color(0xFF09101C);
  static const Color success = Color(0xFF1FA34A);
  static const Color warning = Color(0xFFF1B41A);
  static const Color danger = Color(0xFFD94A45);
}

class FiduciaTheme {
  FiduciaTheme._();

  /// Icons + nav bar contrast vs scaffold (fixes unreadable status bar in light theme).
  static SystemUiOverlayStyle systemUiOverlayForBrightness(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          dark ? FiduciaColors.surfaceDark : FiduciaColors.surfaceLight,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FiduciaColors.navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: FiduciaColors.navy,
      secondary: FiduciaColors.green,
      tertiary: FiduciaColors.lime,
      surface: Colors.white,
      error: FiduciaColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FiduciaColors.surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: FiduciaColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE1E7F0)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FiduciaColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FiduciaColors.navy,
          side: const BorderSide(color: FiduciaColors.navy),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD4DCE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD4DCE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: FiduciaColors.green, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        selectedColor: FiduciaColors.navy,
        backgroundColor: const Color(0xFFE8EDF5),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FiduciaColors.green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: FiduciaColors.lime,
      secondary: FiduciaColors.green,
      tertiary: FiduciaColors.navy,
      surface: const Color(0xFF101B2E),
      error: const Color(0xFFFF7B74),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FiduciaColors.surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111D31),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1D2B45)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FiduciaColors.green,
          foregroundColor: FiduciaColors.navyDeep,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FiduciaColors.lime,
          side: const BorderSide(color: FiduciaColors.lime),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D1728),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF24324A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF24324A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: FiduciaColors.green, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        selectedColor: FiduciaColors.green,
        backgroundColor: const Color(0xFF18253C),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
