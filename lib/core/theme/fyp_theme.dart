import 'package:flutter/material.dart';

import 'brand_colors.dart';

abstract final class FypTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.navy,
      onPrimary: Colors.white,
      primaryContainer: BrandColors.navyTint,
      onPrimaryContainer: BrandColors.navy,
      secondary: BrandColors.green,
      onSecondary: Colors.white,
      secondaryContainer: BrandColors.greenTint,
      onSecondaryContainer: BrandColors.greenText,
      error: BrandColors.error,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: BrandColors.ink,
      onSurfaceVariant: Color(0xFF64748B),
      outlineVariant: Color(0xFFE2E8EF),
    );
    return _base(scheme, BrandColors.background);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.darkNavyText,
      onPrimary: BrandColors.darkBackground,
      primaryContainer: Color(0xFF232D58),
      onPrimaryContainer: Colors.white,
      secondary: BrandColors.greenAccentDark,
      onSecondary: BrandColors.darkBackground,
      secondaryContainer: Color(0xFF13382C),
      onSecondaryContainer: Color(0xFF6EE7B7),
      error: Color(0xFFF2B8B5),
      onError: BrandColors.darkBackground,
      surface: BrandColors.darkSurface,
      onSurface: BrandColors.darkTextPrimary,
      onSurfaceVariant: BrandColors.darkTextSecondary,
      outlineVariant: Color(0xFF2A3668),
    );
    return _base(scheme, BrandColors.darkBackground);
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    final isDark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? BrandColors.darkSurface : BrandColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? BrandColors.greenAccentDark : BrandColors.greenText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF131A38) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? BrandColors.greenAccentDark : BrandColors.green,
      ),
    );
  }
}
