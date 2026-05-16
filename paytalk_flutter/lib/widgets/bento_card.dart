import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bento-style card with liquid glass effect.
/// Frosted background with subtle refraction border — Apple aesthetic.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (color ?? Colors.white).withOpacity(0.55),
                (color ?? Colors.white).withOpacity(0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: glassBorder
                ? Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.06),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
