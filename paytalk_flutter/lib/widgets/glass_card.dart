import 'package:flutter/material.dart';

/// Glassmorphic card widget matching the wireframe "glass-card" CSS class.
/// Uses BackdropFilter for blur + semi-transparent white background.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 20.0,
    this.color,
    this.padding,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.1),
          ),
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }
}
