import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated mesh gradient background with drifting gradient blobs.
/// Premium, liquid-glass Apple-like aesthetic.
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
      duration: const Duration(seconds: 20),
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
        final height = MediaQuery.of(context).size.height;
        final width = MediaQuery.of(context).size.width;

        return Stack(
          children: [
            // Base background color
            Container(color: const Color(0xFFF3F4F6)),
            
            // Blob 1: Vibrant Blue
            Positioned(
              top: -100 + (100 * math.sin(_controller.value * 2 * math.pi)),
              left: -100 + (100 * math.cos(_controller.value * 2 * math.pi)),
              child: const _GradientBlob(
                color: Color(0xFF6366F1),
                size: 700,
                opacity: 0.35,
              ),
            ),
            // Blob 2: Cyan/Teal
            Positioned(
              top: height * 0.4 + (80 * math.cos(_controller.value * 1.5 * math.pi)),
              right: -150 + (120 * math.sin(_controller.value * 1.5 * math.pi)),
              child: const _GradientBlob(
                color: Color(0xFF06B6D4),
                size: 600,
                opacity: 0.3,
              ),
            ),
            // Blob 3: Pink/Magenta
            Positioned(
              bottom: -150 + (150 * math.sin((_controller.value + 0.5) * 2 * math.pi)),
              left: -100 + (100 * math.cos((_controller.value + 0.5) * 2 * math.pi)),
              child: const _GradientBlob(
                color: Color(0xFFEC4899),
                size: 800,
                opacity: 0.25,
              ),
            ),
            // Blob 4: Soft Purple
            Positioned(
              top: height * 0.1 + (120 * math.sin((_controller.value + 0.25) * 2 * math.pi)),
              left: width * 0.3 + (150 * math.cos((_controller.value + 0.25) * 2 * math.pi)),
              child: const _GradientBlob(
                color: Color(0xFF8B5CF6),
                size: 600,
                opacity: 0.25,
              ),
            ),
            // Light overlay to smooth out gradients
            Container(
              color: Colors.white.withOpacity(0.2),
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
  final double opacity;

  const _GradientBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}
