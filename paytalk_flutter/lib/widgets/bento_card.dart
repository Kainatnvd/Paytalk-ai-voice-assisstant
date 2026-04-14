import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool hasShadow;

  const BentoCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 32.0,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: child,
    );
  }
}
