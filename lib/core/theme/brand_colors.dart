import 'package:flutter/material.dart';

/// Future Youth Platform brand palette.
///
/// The two identity colors are navy `#263778` and green `#00A651`.
/// Everything else is a tint or a contrast-safe variant of those two.
///
/// Contrast notes (WCAG, measured):
/// - navy on white ............ 11.05:1  (fine for any text)
/// - green `#00A651` on white .. 3.19:1   (large/bold text and icons ONLY)
/// - [greenText] on white ...... 5.05:1   (use this for green text and links)
/// - [darkBackground] on green . 5.62:1   (use dark text, not white, on green fills)
abstract final class BrandColors {
  // Identity colors.
  static const Color navy = Color(0xFF263778);
  static const Color green = Color(0xFF00A651);

  // Contrast-safe variant of the green for text/links on light backgrounds.
  static const Color greenText = Color(0xFF00803F);

  // Light tints.
  static const Color navyTint = Color(0xFFE8ECF7);
  static const Color greenTint = Color(0xFFEAF7F0);
  static const Color background = Color(0xFFF7F9FC);
  static const Color ink = Color(0xFF111827);

  // Dark theme.
  static const Color darkBackground = Color(0xFF0F1530);
  static const Color darkSurface = Color(0xFF121A3A);
  static const Color darkNavyText = Color(0xFF9FB0E8);

  static const Color error = Color(0xFFB3261E);
}
