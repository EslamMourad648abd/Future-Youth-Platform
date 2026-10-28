import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Light and dark themes for the Future Youth Platform.
///
/// Rules of thumb (see docs/ARCHITECTURE.md, "Brand"):
/// - Navy is the primary color: app bars, primary buttons, headings.
/// - Green is the accent: progress, success, selected states, highlights.
/// - Never put small white text on a green fill (3.19:1). Use dark text.
abstract final class FypTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.navy,
      onPrimary: Colors.white,
      primaryContainer: BrandColors.navyTint,
      onPrimaryContainer: BrandColors.navy,
      secondary: BrandColors.green,
      onSecondary: BrandColors.darkBackground,
      secondaryContainer: BrandColors.greenTint,
      onSecondaryContainer: BrandColors.greenText,
      error: BrandColors.error,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: BrandColors.ink,
    );
    return _base(scheme, BrandColors.background);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.darkNavyText,
      onPrimary: BrandColors.darkBackground,
      primaryContainer: BrandColors.navy,
      onPrimaryContainer: Colors.white,
      secondary: BrandColors.green,
      onSecondary: BrandColors.darkBackground,
      secondaryContainer: BrandColors.greenText,
      onSecondaryContainer: Colors.white,
      error: Color(0xFFF2B8B5),
      onError: BrandColors.darkBackground,
      surface: BrandColors.darkSurface,
      onSurface: Colors.white,
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
          foregroundColor: isDark ? BrandColors.green : BrandColors.greenText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
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
          side: BorderSide(
            color: isDark ? const Color(0xFF26305E) : const Color(0xFFE2E8EF),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.green,
      ),
    );
  }
}
