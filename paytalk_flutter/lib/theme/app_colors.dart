import 'package:flutter/material.dart';

class AppColors {
  // Surface Hierarchy
  static const Color background = Color(0xFFF5F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEEF1F3);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFF1F5F9);

  // Brand Colors
  static const Color primary = Color(0xFF6366F1); // purplish-blue
  static const Color primaryContainer = Color(0xFFEEF2FF);
  static const Color primaryHover = Color(0xFF4F46E5);
  static const Color primaryGradientStart = Color(0xFF4647D3);
  static const Color primaryGradientEnd = Color(0xFF9396FF);

  // Neutrals / On-Surface
  static const Color onSurface = Color(0xFF1E1B4B); // Deep indigo
  static const Color onSurfaceVariant = Color(0xFF4338CA);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFABADAF); // Ghost border base

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGradientStart, primaryGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getGhostBorder() => outlineVariant.withOpacity(0.15);
}
