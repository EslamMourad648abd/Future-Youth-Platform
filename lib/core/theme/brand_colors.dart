import 'package:flutter/material.dart';

/// Future Youth Platform brand palette.
///
/// Identity colors:
/// - Navy: `#263778`
/// - Emerald Green: `#00A651`
abstract final class BrandColors {
  // Identity colors.
  static const Color navy = Color(0xFF263778);
  static const Color green = Color(0xFF00A651);

  // Contrast-safe variants.
  static const Color greenText = Color(0xFF00803F);
  static const Color greenAccentDark = Color(0xFF10B981);

  // Light Theme Tints.
  static const Color navyTint = Color(0xFFE8ECF7);
  static const Color greenTint = Color(0xFFEAF7F0);
  static const Color background = Color(0xFFF8FAFC);
  static const Color ink = Color(0xFF0F172A);

  // Dark Theme Tints (Eye-pleasing, glare-free midnight slate palette).
  static const Color darkBackground = Color(0xFF0F1530);
  static const Color darkSurface = Color(0xFF1A234A);
  static const Color darkNavyText = Color(0xFF818CF8);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static const Color error = Color(0xFFB3261E);
}
