import 'package:flutter/material.dart';

import 'store_animation.dart';

class HomeDiwaliGreeting extends StatefulWidget {
  final bool isVisible;
  final String greeting;
  final String userName;
  final VoidCallback? onDismiss;

  const HomeDiwaliGreeting({
    super.key,
    this.isVisible = true,
    this.greeting = 'Hello',
    this.userName = 'there',
    this.onDismiss,
  });

  @override
  State<HomeDiwaliGreeting> createState() => _HomeDiwaliGreetingState();
}

class _HomeDiwaliGreetingState extends State<HomeDiwaliGreeting>
    with WidgetsBindingObserver {
  static const _animationAspectRatio = 600 / 1253;

  bool _appIsForeground = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsForeground = WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_appIsForeground == isForeground) return;
    setState(() => _appIsForeground = isForeground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _dismiss() {
    final onDismiss = widget.onDismiss;
    if (onDismiss != null) {
      onDismiss();
    } else {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final shouldPlay = widget.isVisible &&
        _appIsForeground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xF20D0905)),
            Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: width / _animationAspectRatio,
                  child: StoreAnimation(
                    assetPath: 'animations/diwali_greeting.lottie',
                    size: width,
                    aspectRatio: _animationAspectRatio,
                    semanticLabel: 'Diwali festival animation',
                    loop: true,
                    isVisible: shouldPlay,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
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
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: 'Close Diwali animation',
                  onPressed: _dismiss,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xAA110B07),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
