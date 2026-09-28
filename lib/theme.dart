import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'data/hive_service.dart';

class AppColors {
  static const bgTop = Color(0xFF05070D);
  static const bgBottom = Color(0xFF0B1220);
  static const emerald = Color(0xFF10B981);
  static const emeraldDim = Color(0xFF065F46);
  static const gold = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const cardBorder = Color(0x1FFFFFFF); // white 12%
}

/// BuildContext helpers for theme-aware text colors.
/// Dark mode keeps the existing palette; light mode uses slate tones.
extension ThemeCtx on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get tTextPrimary => isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
  Color get tTextSecondary => isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);
  Color get tTextMuted => isDarkMode ? AppColors.textMuted : const Color(0xFF94A3B8);
}

/// 'dark' | 'light' | 'system' — persisted in the Hive settings box.
/// Defaults to 'dark' to preserve the current look.
ThemeMode themeModeFromSettings() {
  switch (HiveService.settings.get('themeMode') as String?) {
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    case 'dark':
    default:
      return ThemeMode.dark;
  }
}

Future<void> setThemeModeSetting(String v) async {
  await HiveService.settings.put('themeMode', v);
}

TextStyle moneyStyle(double size,
    {Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w700}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: -0.3,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.emerald,
    secondary: AppColors.gold,
    error: AppColors.danger,
    surface: Color(0xFF0B1220),
  );
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.bgBottom,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF111A2E),
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0E1626),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: Colors.white.withOpacity(0.08),
  );
}

/// Light glassmorphism theme: soft light surfaces, dark slate text,
/// same emerald brand accents and 16–24px radii as the dark theme.
ThemeData buildLightTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.emerald,
    secondary: AppColors.gold,
    error: AppColors.danger,
    surface: Colors.white,
  );
  final base = ThemeData.light(useMaterial3: true);
  const ink = Color(0xFF0F172A);
  return base.copyWith(
    colorScheme: scheme,
    // Transparent so AppBackground's light gradient shows through.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: const Color(0xFFF1F5F9),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: ink),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: const TextStyle(color: ink),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ink.withOpacity(0.12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: ink.withOpacity(0.10)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: ink.withOpacity(0.10),
  );
}
