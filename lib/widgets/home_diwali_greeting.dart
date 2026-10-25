import 'package:flutter/material.dart';

import 'store_animation.dart';

class HomeDiwaliGreeting extends StatelessWidget {
  final bool isVisible;
  final String greeting;
  final String userName;
  final VoidCallback onDismiss;

  const HomeDiwaliGreeting({
    super.key,
    required this.isVisible,
    required this.greeting,
    required this.userName,
    required this.onDismiss,
  });

  static const _animationPath = 'animations/festival_splash.lottie';
  static const _animationAspectRatio = 600 / 1253;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final animationWidth =
            width < constraints.maxHeight * _animationAspectRatio
                ? width
                : constraints.maxHeight * _animationAspectRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0xFF1A0F05)),
            ),
            _buildGreeting(context, animationWidth),
          ],
        );
      },
    );
  }

  Widget _buildGreeting(BuildContext context, double animationWidth) {
    final shouldPlay = isVisible && !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Festival of Lights greeting',
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: StoreAnimation(
              assetPath: _animationPath,
              size: animationWidth,
              aspectRatio: _animationAspectRatio,
              semanticLabel: 'Animated Diwali Festival of Lights greeting',
              loop: true,
              isVisible: shouldPlay,
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  child: Text(
                    '$greeting, $userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A3417),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton.filledTonal(
                tooltip: 'Close Diwali animation',
                onPressed: onDismiss,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xAA110B07),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
