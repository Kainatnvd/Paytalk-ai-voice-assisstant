import 'package:flutter/material.dart';

/// Design System: Ethereal Professional — "The Digital Curator"
/// Purplish-blue accent on a pure white/light base.
class AppColors {
  // ── Surface Hierarchy (Tonal Layering) ─────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF9FAFB);
  static const Color surfaceContainerHigh = Color(0xFFF3F4F6);
  static const Color surfaceContainerHighest = Color(0xFFE5E7EB);

  // ── Brand Colors ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryHover = Color(0xFF4F46E5);
  static const Color primaryContainer = Color(0xFFEEF2FF);
  static const Color onPrimaryContainer = Color(0xFF312E81);
  static const Color secondary = Color(0xFF818CF8);
  static const Color secondaryContainer = Color(0xFFF5F3FF);
  static const Color onSecondaryContainer = Color(0xFF4C1D95);

  // ── On-Surface ─────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF1E1B4B); // Deep indigo
  static const Color onSurfaceVariant = Color(0xFF4338CA);
  static const Color textMuted = Color(0xFF6B7280);

  // ── Outlines ───────────────────────────────────────────────────────
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFF3F4F6);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Helpers ────────────────────────────────────────────────────────
  static Color ghostBorder() => outline.withOpacity(0.5);
}
