import 'package:flutter/material.dart';

/// Design System: Liquid Glass — Apple-inspired premium fintech palette.
/// Deep indigo/violet accent with luminous teal accents on a frosted base.
class AppColors {
  // ── Surface Hierarchy (Tonal Layering) ─────────────────────────────
  static const Color background = Color(0xFFF0F2F8);
  static const Color surface = Color(0xFFF5F7FD);
  static const Color surfaceContainer = Color(0xFFF9FAFB);
  static const Color surfaceContainerHigh = Color(0xFFF3F4F6);
  static const Color surfaceContainerHighest = Color(0xFFE5E7EB);

  // ── Brand Colors ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF5B5FE6);
  static const Color primaryHover = Color(0xFF4B4FD6);
  static const Color primaryContainer = Color(0xFFECEDFF);
  static const Color onPrimaryContainer = Color(0xFF2D2F7A);
  static const Color secondary = Color(0xFF818CF8);
  static const Color secondaryContainer = Color(0xFFF0EFFF);
  static const Color onSecondaryContainer = Color(0xFF3B1D95);

  // ── Accent (Teal Glow) ────────────────────────────────────────────
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentContainer = Color(0xFFE0FBFF);

  // ── On-Surface ─────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF1A1B3A);
  static const Color onSurfaceVariant = Color(0xFF3E3FA8);
  static const Color textMuted = Color(0xFF6B7280);

  // ── Outlines ───────────────────────────────────────────────────────
  static const Color outline = Color(0xFFE2E5F0);
  static const Color outlineVariant = Color(0xFFF3F4F6);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color error = Color(0xFFF43F5E);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B5FE6), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF4B4FD6), Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x40FFFFFF), Color(0x10FFFFFF)],
  );

  // ── Helpers ────────────────────────────────────────────────────────
  static Color ghostBorder() => outline.withOpacity(0.5);
}
