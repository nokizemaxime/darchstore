import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF10141A);
  static const raised = Color(0xFF181E27);
  static const panel = Color(0xFF212A36);
  static const line = Color(0xFF313C4B);
  static const parchment = Color(0xFFF3EDE3);
  static const muted = Color(0xFFB7C0CC);
  static const copper = Color(0xFFE2A36B);
  static const inkOnCopper = Color(0xFF2A1608);
  static const sage = Color(0xFF8FBF9F);
  static const danger = Color(0xFFE07A6A);
}

ThemeData buildDarchTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.copper,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.copper,
        onPrimary: AppColors.inkOnCopper,
        secondary: AppColors.sage,
        onSecondary: const Color(0xFF102117),
        surface: AppColors.ink,
        onSurface: AppColors.parchment,
        error: AppColors.danger,
        onError: const Color(0xFF2C0E0A),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    dividerColor: AppColors.line,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.parchment,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.raised,
      indicatorColor: AppColors.copper.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.copper : AppColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.copper : AppColors.muted,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.inkOnCopper,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.panel,
      selectedColor: AppColors.copper.withValues(alpha: 0.22),
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(color: AppColors.parchment),
      secondaryLabelStyle: const TextStyle(color: AppColors.copper),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.copper,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panel,
      contentTextStyle: TextStyle(color: AppColors.parchment),
    ),
  );
}
