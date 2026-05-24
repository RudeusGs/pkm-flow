import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFBFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF2EEE8);
  static const line = Color(0xFFE8E2DA);
  static const ink = Color(0xFF252321);
  static const muted = Color(0xFF75716C);
  static const accent = Color(0xFF2E6F5E);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFB7791F);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.soft,
        side: const BorderSide(color: AppColors.line),
      ),
    );
  }
}
