import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bento-style card matching wireframe glass-panel / bento-card CSS.
/// White background with subtle ambient shadow — no borders per design system.
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final bool glassBorder;

  const BentoCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.color,
    this.glassBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: glassBorder
            ? Border.all(color: AppColors.primaryContainer)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
