import 'package:flutter/material.dart';

import 'store_animation.dart';

class HomeDiwaliGreeting extends StatefulWidget {
  final bool isVisible;
  final String greeting;
  final String userName;

  const HomeDiwaliGreeting({
    super.key,
    this.isVisible = true,
    this.greeting = 'Hello',
    this.userName = 'there',
  });

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    StoreAnimation(
                      assetPath: 'animations/diwali_greeting.lottie',
                      size: animationWidth,
                      aspectRatio: animationAspectRatio,
                      semanticLabel: 'Diwali festival animation',
                      loop: true,
                      isVisible: widget.isVisible && _showAnimation,
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xEFFFFFFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                '${widget.greeting}, ${widget.userName}',
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
                    ),
                  ],
                ),
                if (_showAnimation)
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
            ),
          );
        },
      ),
    );
  }
}
