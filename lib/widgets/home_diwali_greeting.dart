import 'package:flutter/material.dart';

import 'store_animation.dart';

class HomeDiwaliGreeting extends StatefulWidget {
  const HomeDiwaliGreeting({super.key});

  @override
  State<HomeDiwaliGreeting> createState() => _HomeDiwaliGreetingState();
}

class _HomeDiwaliGreetingState extends State<HomeDiwaliGreeting> {
  bool _showAnimation = true;

  void _dismissAnimation() {
    setState(() => _showAnimation = false);
  }

  @override
  Widget build(BuildContext context) {
    const animationAspectRatio = 600 / 1253;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final animationWidth = constraints.maxWidth;

          return AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showAnimation
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StoreAnimation(
                        assetPath: 'animations/diwali_greeting.lottie',
                        size: animationWidth,
                        aspectRatio: animationAspectRatio,
                        semanticLabel: 'Diwali festival animation',
                        loop: true,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Dismiss Diwali animation',
                          onPressed: _dismissAnimation,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded),
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'FESTIVAL OF LIGHT',
                        style: TextStyle(
                          color: Color(0xFFAC4A19),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
