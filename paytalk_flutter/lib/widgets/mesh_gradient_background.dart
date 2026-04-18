import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated mesh gradient background with drifting gradient blobs.
/// Matches the wireframe login screen background with gradient-blob animation.
class AnimatedGradientBlob extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBlob({super.key, required this.child});

  @override
  State<AnimatedGradientBlob> createState() => _AnimatedGradientBlobState();
}

class _AnimatedGradientBlobState extends State<AnimatedGradientBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: AppColors.background),
            // Blob 1: top-left
            Positioned(
              top: -200 + (40 * math.sin(_controller.value * 2 * math.pi)),
              left: -200 + (50 * math.cos(_controller.value * 2 * math.pi)),
              child: _GradientBlob(
                color: AppColors.primary.withOpacity(0.15),
                size: 600,
              ),
            ),
            // Blob 2: bottom-right
            Positioned(
              bottom: -200 +
                  (50 *
                      math.sin(
                          (_controller.value + 0.5) * 2 * math.pi)),
              right: -200 +
                  (40 *
                      math.cos(
                          (_controller.value + 0.5) * 2 * math.pi)),
              child: _GradientBlob(
                color: AppColors.secondary.withOpacity(0.15),
                size: 700,
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _GradientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GradientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}
