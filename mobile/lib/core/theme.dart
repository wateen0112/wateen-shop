/// Design tokens — mirrors the `:root` variables of `frontend/src/styles.css`.
library;

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFFEEF2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF0F766E);
  static const Color primary600 = Color(0xFF0D9488);
  static const Color primarySoft = Color(0xFFCCFBF1);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warn = Color(0xFFB45309);

  /// App bar gradient (135deg, #0f766e → #0d9488 → #14b8a6).
  static const List<Color> appBarGradient = <Color>[
    Color(0xFF0F766E),
    Color(0xFF0D9488),
    Color(0xFF14B8A6),
  ];

  static const Color appBarShadow = Color(0x1F0D9488);
  static const Color softDanger = Color(0xFFFEE2E2);
  static const Color softSuccess = Color(0xFFDCFCE7);
  static const Color softWarn = Color(0xFFFEF3C7);
  static const Color softGrey = Color(0xFFF1F5F9);
  static const Color fieldBg = Color(0xFFF8FAFC);
}

class AppRadius {
  const AppRadius._();

  static const double card = 20;
  static const double field = 14;
  static const double button = 14;
  static const double pill = 999;
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primary600,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.line,
  );

  final TextTheme text = const TextTheme().apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: AppColors.muted),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.primary600, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
  );
}
