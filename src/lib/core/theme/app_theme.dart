import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F0F0F);
  static const surface = Color(0xFF171717);
  static const surfaceAlt = Color(0xFF191919);
  static const hover = Color(0xFF202020);
  static const line = Color(0xFF2A2A2A);
  static const ink = Color(0xFFF7F7F5);
  static const muted = Color(0xFF9B9B9B);
  static const subtle = Color(0xFF707070);
  static const soft = Color(0xFF202020);
  static const accent = Color(0xFFEDEDEA);
  static const danger = Color(0xFFE06C75);
  static const dangerSurface = Color(0xFF2A1719);
  static const success = Color(0xFF6AAE7F);
  static const warning = Color(0xFFD6A85F);
}

class AppTheme {
  static ThemeData light() => dark();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.ink,
      onPrimary: AppColors.background,
      secondary: AppColors.muted,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      outline: AppColors.line,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: Color(0x33484848),
        selectionHandleColor: AppColors.ink,
      ),
      textTheme: const TextTheme(
        headlineLarge:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
        headlineMedium:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
        headlineSmall:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
        titleLarge:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        titleMedium:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        titleSmall:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.muted),
        labelLarge:
            TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(
            color: AppColors.subtle, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(
            color: AppColors.muted, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: inputBorder(AppColors.line),
        enabledBorder: inputBorder(AppColors.line),
        focusedBorder: inputBorder(AppColors.ink, width: 1.1),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, width: 1.1),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 46),
          elevation: 0,
          backgroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.hover,
          foregroundColor: AppColors.background,
          disabledForegroundColor: AppColors.subtle,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.subtle,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 56,
        indicatorColor: AppColors.hover,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            height: 1,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: AppColors.background,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.hover,
        contentTextStyle:
            const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: const TextStyle(color: AppColors.muted, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        textStyle:
            const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}
