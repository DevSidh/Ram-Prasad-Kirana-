import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'frosted_panel.dart';

class AuthSurface extends StatelessWidget {
  final Widget child;

  const AuthSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final pagePadding = isCompact ? 12.0 : 20.0;
        final panelPadding = isCompact ? 18.0 : 24.0;

        return ColoredBox(
          color: AppConstants.backgroundLight,
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -90,
                child: _BackdropGlow(
                  size: 300,
                  color: AppConstants.primary.withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                bottom: -160,
                left: -120,
                child: _BackdropGlow(
                  size: 340,
                  color: AppConstants.primary.withValues(alpha: 0.18),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pagePadding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FrostedPanel(
                      padding: EdgeInsets.all(panelPadding),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(28)),
                      tint: isDark
                          ? const Color(0xFF111714)
                          : const Color(0xFFF8FCF8),
                      opacity: isDark ? 0.96 : 0.97,
                      blur: 24,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
