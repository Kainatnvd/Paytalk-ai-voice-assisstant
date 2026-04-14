import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurface,
        letterSpacing: -0.02 * 32, // Intentional tight display
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.onSurface,
        height: 1.6, // Airy line height
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.onSurfaceVariant.withOpacity(0.8),
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.onSurfaceVariant.withOpacity(0.6),
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurfaceVariant.withOpacity(0.8),
        letterSpacing: 0.05 * 11, // Metadata uppercase style
      );

  static TextStyle get urduText => const TextStyle(
        fontFamily: 'NotoNastaliqUrdu',
        fontSize: 18,
        color: AppColors.primary,
      );
}
