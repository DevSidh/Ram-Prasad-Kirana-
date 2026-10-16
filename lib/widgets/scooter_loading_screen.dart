import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScooterLoadingScreen extends StatefulWidget {
  final Future<void> Function() init;
  final ValueChanged<Object?> onFinished;
  final Duration minDuration;
  final String title;
  final String subtitle;

  const ScooterLoadingScreen({
    super.key,
    required this.init,
    required this.onFinished,
    required this.title,
    required this.subtitle,
    this.minDuration = const Duration(seconds: 3),
  });

  @override
  State<ScooterLoadingScreen> createState() => _ScooterLoadingScreenState();
}

class _ScooterLoadingScreenState extends State<ScooterLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: widget.minDuration,
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  int _laps = 0;
  bool _initDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startInit();
    _runAnimation();
  }

  Future<void> _startInit() async {
    try {
      await widget.init();
    } catch (error) {
      _error = error;
    } finally {
      _initDone = true;
    }
  }

  Future<void> _runAnimation() async {
    do {
      await _move.forward(from: 0);
      if (!mounted) return;
      _laps++;
    } while (!_initDone);

    await _exit.forward();
    if (mounted) widget.onFinished(_error);
  }

  @override
  void dispose() {
    _move.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;

    return Scaffold(
      key: const ValueKey('scooter-loading-screen'),
      body: FadeTransition(
        opacity: ReverseAnimation(_exit),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final height = box.maxHeight;
            final scooterWidth = (width * 0.6).clamp(180.0, 320.0);
            final scale = scooterWidth / 200;
            final groundY = height * 0.48;

            return AnimatedBuilder(
              animation: _move,
              builder: (context, _) {
                final progress = _move.value;
                final travel = _laps + progress;
                final eased = Curves.easeInOutSine.transform(progress);
                final x = -scooterWidth + (width + scooterWidth) * eased;
                final bob = math.sin(travel * math.pi * 28) * 1.4;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.surface,
                              Color.lerp(
                                theme.colorScheme.surface,
                                const Color(0xFFFFC21A),
                                isDark ? 0.08 : 0.14,
                              )!,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoadPainter(
                          travel: travel,
                          groundY: groundY,
                          color: ink,
                        ),
                      ),
                    ),
                    Positioned(
                      left: x,
                      top: groundY - 129 * scale,
                      width: scooterWidth,
                      height: 140 * scale,
                      child: CustomPaint(
                        painter: _ScooterPainter(
                          wheelAngle: travel * math.pi * 14,
                          bob: bob,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 28,
                      right: 28,
                      bottom: height * 0.13,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AnimatedTitle(
                            animation: _move,
                            laps: _laps,
                            title: widget.title,
                            subtitle: widget.subtitle,
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: math.min(260, width * 0.7),
                              height: 6,
                              child: LinearProgressIndicator(
                                value: _laps == 0 ? eased : null,
                                backgroundColor: ink.withValues(alpha: 0.10),
                                color: const Color(0xFFFFC21A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedTitle extends StatelessWidget {
  final Animation<double> animation;
  final int laps;
  final String title;
  final String subtitle;

  const _AnimatedTitle({
    required this.animation,
    required this.laps,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final dots = ((laps + animation.value) * 4).floor() % 4;
          final style = Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    TextSpan(text: title),
                    TextSpan(text: '.' * dots),
                    TextSpan(
                      text: '.' * (3 - dots),
                      style: const TextStyle(color: Colors.transparent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      );
}

class _RoadPainter extends CustomPainter {
  final double travel;
  final double groundY;
  final Color color;

  const _RoadPainter({
    required this.travel,
    required this.groundY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = color.withValues(alpha: 0.07);
    const clouds = [
      [0.10, 0.18, 70.0, 60.0],
      [0.55, 0.28, 50.0, 90.0],
      [0.85, 0.12, 60.0, 45.0],
      [0.35, 0.36, 40.0, 120.0],
    ];
    for (final cloud in clouds) {
      final span = size.width + 240;
      final cx = ((cloud[0] * size.width - travel * cloud[3] * 10) % span +
              span) %
          span -
          120;
      final cy = size.height * cloud[1];
      final radius = cloud[2] / 2;
      canvas.drawCircle(Offset(cx, cy), radius * 0.7, cloudPaint);
      canvas.drawCircle(
        Offset(cx + radius * 0.8, cy - radius * 0.3),
        radius,
        cloudPaint,
      );
      canvas.drawCircle(
        Offset(cx + radius * 1.7, cy),
        radius * 0.7,
        cloudPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - radius * 0.2, cy, radius * 2.5, radius * 0.7),
          Radius.circular(radius * 0.35),
        ),
        cloudPaint,
      );
    }

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = 2,
    );

    const dash = 30.0;
    const gap = 24.0;
    const period = dash + gap;
    final offset = (travel * 700) % period;
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = -period - offset; x < size.width + period; x += period) {
      canvas.drawLine(
        Offset(x, groundY + 18),
        Offset(x + dash, groundY + 18),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.travel != travel || oldDelegate.groundY != groundY;
}

class _ScooterPainter extends CustomPainter {
  final double wheelAngle;
  final double bob;
  final bool isDark;

  const _ScooterPainter({
    required this.wheelAngle,
    required this.bob,
    required this.isDark,
  });

  static const _yellow = Color(0xFFFFC21A);
  static const _outlineColor = Colors.black;

  void _outline(Canvas canvas, Path path, Color fill) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = _outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _limb(Canvas canvas, List<Offset> points, double width, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final stroke in [
      Paint()
        ..color = _outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    ]) {
      canvas.drawPath(path, stroke);
    }
  }

  void _wheel(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      17,
      Paint()..color = isDark ? const Color(0xFF3A3A3A) : Colors.black,
    );
    canvas.drawCircle(center, 9.5, Paint()..color = Colors.white);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(wheelAngle);
    final spoke = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 4; index++) {
      final angle = index * math.pi / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * 8, math.sin(angle) * 8),
        spoke,
      );
    }
    canvas.restore();
    canvas.drawCircle(center, 3, Paint()..color = Colors.black);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200);

    _wheel(canvas, const Offset(45, 112));
    _wheel(canvas, const Offset(158, 112));
    canvas.save();
    canvas.translate(0, bob);

    _limb(canvas, const [Offset(146, 58), Offset(158, 112)], 3, Colors.black);
    _outline(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(84, 96, 56, 7),
          const Radius.circular(3),
        )),
      Colors.white,
    );
    _outline(
      canvas,
      Path()
        ..moveTo(22, 112)
        ..cubicTo(20, 88, 38, 80, 62, 80)
        ..lineTo(92, 80)
        ..lineTo(96, 98)
        ..lineTo(70, 100)
        ..cubicTo(66, 108, 60, 114, 50, 114)
        ..close(),
      _yellow,
    );
    _outline(
      canvas,
      Path()
        ..moveTo(130, 102)
        ..quadraticBezierTo(132, 74, 140, 56)
        ..lineTo(152, 56)
        ..quadraticBezierTo(150, 80, 150, 102)
        ..close(),
      _yellow,
    );
    _outline(
      canvas,
      Path()
        ..moveTo(142, 108)
        ..quadraticBezierTo(158, 84, 178, 100)
        ..lineTo(173, 105)
        ..quadraticBezierTo(158, 95, 148, 111)
        ..close(),
      _yellow,
    );
    _outline(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(48, 72, 52, 9),
          const Radius.circular(4),
        )),
      Colors.white,
    );
    _outline(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 42, 46, 32),
          const Radius.circular(6),
        )),
      const Color(0xFFE6E6E6),
    );

    final line = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12, 52), const Offset(58, 52), line);
    canvas.drawLine(const Offset(30, 42), const Offset(30, 74), line);
    canvas.drawLine(const Offset(40, 42), const Offset(40, 74), line);

    _limb(canvas, const [Offset(74, 72), Offset(116, 70), Offset(120, 96)], 11,
        const Color(0xFFEFEFEF));
    _outline(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(112, 94, 20, 8),
          const Radius.circular(4),
        )),
      Colors.black,
    );
    _outline(
      canvas,
      Path()
        ..moveTo(64, 74)
        ..lineTo(72, 38)
        ..quadraticBezierTo(82, 28, 94, 34)
        ..lineTo(98, 50)
        ..lineTo(88, 76)
        ..close(),
      _yellow,
    );
    _limb(canvas, const [Offset(90, 42), Offset(116, 58), Offset(142, 50)], 8,
        _yellow);
    _limb(canvas, const [Offset(140, 50), Offset(158, 45)], 3.5, Colors.black);
    canvas.drawCircle(const Offset(161, 48), 5, Paint()..color = _yellow);
    canvas.drawCircle(
      const Offset(161, 48),
      5,
      Paint()
        ..color = _outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    canvas.drawCircle(
      const Offset(92, 25),
      7,
      Paint()..color = const Color(0xFFFFE3CC),
    );
    canvas.drawCircle(
      const Offset(92, 25),
      7,
      Paint()
        ..color = _outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final helmet = Path()
      ..moveTo(75, 24)
      ..arcToPoint(
        const Offset(99, 22),
        radius: const Radius.circular(12),
        clockwise: true,
      )
      ..lineTo(88, 20)
      ..close();
    _outline(canvas, helmet, _yellow);

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScooterPainter oldDelegate) =>
      oldDelegate.wheelAngle != wheelAngle ||
      oldDelegate.bob != bob ||
      oldDelegate.isDark != isDark;
}
