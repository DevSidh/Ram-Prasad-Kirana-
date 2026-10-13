import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color tint;
  final double opacity;
  final double blur;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.tint = Colors.white,
    this.opacity = 0.76,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: opacity),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.72),
          width: isDark ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123E2E).withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (blur <= 0) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: panel,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      ),
    );
  }
}
