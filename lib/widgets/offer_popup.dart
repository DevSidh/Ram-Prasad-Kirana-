import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/store_offer.dart';
import 'white_matte_video_filter.dart';

const _offerGold = Color(0xFFFFC72C);
const _offerSaffron = Color(0xFFD94A06);
const _offerInk = Color(0xFF241A5C);
const _offerPurple = Color(0xFF3F2080);

class OfferPopup extends StatelessWidget {
  final StoreOffer offer;

  const OfferPopup({super.key, required this.offer});

  static Future<bool?> show(BuildContext context, StoreOffer offer) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close festival offer',
      barrierColor: Colors.black.withValues(alpha: .74),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (context, animation, secondaryAnimation) =>
          OfferPopup(offer: offer),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final disableAnimations = MediaQuery.disableAnimationsOf(context);
        final transition = disableAnimations
            ? const AlwaysStoppedAnimation<double>(1)
            : CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        final opacity = disableAnimations
            ? const AlwaysStoppedAnimation<double>(1)
            : CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: Tween<double>(begin: .7, end: 1).animate(transition),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final videoHeight = (screenHeight * .18).clamp(105.0, 168.0).toDouble();
    final bottomHeight = (screenHeight * .25).clamp(150.0, 230.0).toDouble();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final offerDescription = offer.discountType == OfferDiscountType.percentage
        ? '${offer.percent}% off up to Rs. ${offer.maxDiscount}'
        : 'Rs. ${offer.amount} off';

    return Semantics(
      container: true,
      label: 'Festival special offer: $offerDescription. Coupon ${offer.code}.',
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dialogHeight = math.min(
                constraints.maxHeight,
                videoHeight + bottomHeight * .3 + 440,
              );
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight: constraints.maxHeight,
                ),
                child: SizedBox(
                  height: dialogHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFFAF0), Color(0xFFFFE8C4)],
                        ),
                        border: Border.all(color: _offerGold, width: 3),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: bottomHeight,
                            child: OfferBottomAnimation(height: bottomHeight),
                          ),
                          Positioned.fill(
                            child: TwinklingSparkles(
                              disableAnimations: disableAnimations,
                            ),
                          ),
                          SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _MarigoldGarland(),
                                OfferTopVideo(height: videoHeight),
                                OfferMiddle(
                                  offer: offer,
                                  onClaim: () =>
                                      Navigator.of(context).pop(true),
                                  onMaybeLater: () =>
                                      Navigator.of(context).pop(false),
                                  disableAnimations: disableAnimations,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Semantics(
                              button: true,
                              label: 'Close offer',
                              child: SizedBox.square(
                                dimension: 44,
                                child: IconButton(
                                  tooltip: 'Close offer',
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  icon: const Icon(Icons.close_rounded),
                                  style: IconButton.styleFrom(
                                    foregroundColor: _offerInk,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: .86),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class OfferTopVideo extends StatefulWidget {
  final double height;

  const OfferTopVideo({super.key, required this.height});

  @override
  State<OfferTopVideo> createState() => _OfferTopVideoState();
}

class _OfferTopVideoState extends State<OfferTopVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/diwali_sale.mp4');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() => _initialized = true);
    } catch (error, stackTrace) {
      debugPrint(
          'Unable to play the festival offer video: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    unawaited(_pauseAndDispose());
    super.dispose();
  }

  Future<void> _pauseAndDispose() async {
    try {
      await _controller.pause();
    } catch (error, stackTrace) {
      debugPrint(
          'Unable to pause the festival offer video: $error\n$stackTrace');
    }
    await _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return SizedBox(height: widget.height);
    return SizedBox(
      height: widget.height,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: ClipRect(
            child: ColorFiltered(
              colorFilter: whiteMatteVideoFilter,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
      ),
    );
  }
}

class OfferMiddle extends StatelessWidget {
  final StoreOffer offer;
  final VoidCallback onClaim;
  final VoidCallback onMaybeLater;
  final bool disableAnimations;

  const OfferMiddle({
    super.key,
    required this.offer,
    required this.onClaim,
    required this.onMaybeLater,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.2).toDouble();
    final bottomHeight =
        (MediaQuery.sizeOf(context).height * .25).clamp(150.0, 230.0);
    final isPercentage = offer.discountType == OfferDiscountType.percentage;
    final headline = isPercentage ? '${offer.percent}%' : 'Rs. ${offer.amount}';
    final benefitDescription = isPercentage
        ? 'up to Rs. ${offer.maxDiscount}'
        : offer.minOrderAmount > 0
            ? 'off orders over Rs. ${offer.minOrderAmount}'
            : 'off your order';
    final claimLabel =
        'Claim ${isPercentage ? '${offer.percent}%' : 'Rs. ${offer.amount}'} OFF';
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 2, 22, bottomHeight * .3 + 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FESTIVAL SPECIAL',
              style: TextStyle(
                color: Color(0xFF8A5A00),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      headline,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 76,
                        height: .98,
                        fontWeight: FontWeight.w900,
                        color: _offerPurple,
                        shadows: [
                          Shadow(
                            color: _offerGold,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: -.105,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _offerSaffron,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF9C3204),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        'OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                benefitDescription,
                maxLines: 1,
                style: const TextStyle(
                  color: _offerInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CouponTicket(code: offer.code),
            if (offer.endsAt != null) ...[
              const SizedBox(height: 10),
              OfferCountdown(endsAt: offer.endsAt!),
            ],
            const SizedBox(height: 8),
            _ClaimButton(
              label: claimLabel,
              onPressed: onClaim,
              disableAnimations: disableAnimations,
            ),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: onMaybeLater,
                style: TextButton.styleFrom(
                  foregroundColor: _offerInk,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Maybe later'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CouponTicket extends StatefulWidget {
  final String code;

  const CouponTicket({super.key, required this.code});

  @override
  State<CouponTicket> createState() => _CouponTicketState();
}

class _CouponTicketState extends State<CouponTicket> {
  Timer? _copiedTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    _copiedTimer?.cancel();
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedTicketBorderPainter(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'USE CODE',
                    style: TextStyle(
                      color: Color(0xFF8A5A00),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.code,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _offerInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Copy coupon code',
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _copyCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: _offerInk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_copied ? 'Copied' : 'Copy'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedTicketBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(16),
        ).deflate(1),
      );
    final paint = Paint()
      ..color = const Color(0xFF8E6BD0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 6, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedTicketBorderPainter oldDelegate) => false;
}

class OfferCountdown extends StatefulWidget {
  final DateTime endsAt;

  const OfferCountdown({super.key, required this.endsAt});

  @override
  State<OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<OfferCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    final difference = widget.endsAt.toLocal().difference(DateTime.now());
    _remaining = difference.isNegative ? Duration.zero : difference;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refreshRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant OfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _refreshRemaining();
  }

  void _refreshRemaining() {
    final difference = widget.endsAt.toLocal().difference(DateTime.now());
    setState(() {
      _remaining = difference.isNegative ? Duration.zero : difference;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: _offerInk, fontSize: 13),
        children: [
          const TextSpan(text: 'Offer ends in '),
          TextSpan(
            text: '$hours:$minutes:$seconds',
            style: const TextStyle(
              color: _offerSaffron,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class OfferBottomAnimation extends StatelessWidget {
  final double height;

  const OfferBottomAnimation({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/anar_transparent.webp',
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class TwinklingSparkles extends StatefulWidget {
  final bool disableAnimations;

  const TwinklingSparkles({super.key, required this.disableAnimations});

  @override
  State<TwinklingSparkles> createState() => _TwinklingSparklesState();
}

class _TwinklingSparklesState extends State<TwinklingSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  static const _sparklePositions = <(double, double, double)>[
    (.12, 42, 0),
    (.82, 72, .8),
    (.05, .44, 1.4),
    (.91, .51, .4),
    (.24, .65, 1.1),
    (.73, .72, .2),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.disableAnimations) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TwinklingSparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                for (var index = 0; index < _sparklePositions.length; index++)
                  _Sparkle(
                    left: constraints.maxWidth * _sparklePositions[index].$1,
                    top: _sparklePositions[index].$2 <= 1
                        ? MediaQuery.sizeOf(context).height *
                            _sparklePositions[index].$2
                        : _sparklePositions[index].$2,
                    progress: widget.disableAnimations
                        ? 0
                        : (_controller.value + _sparklePositions[index].$3) % 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double left;
  final double top;
  final double progress;

  const _Sparkle({
    required this.left,
    required this.top,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final twinkle = (math.sin(progress * 2 * math.pi) + 1) / 2;
    final scale = .5 + .6 * twinkle;
    final opacity = .3 + .7 * twinkle;
    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: const Icon(
            Icons.auto_awesome,
            color: _offerGold,
            size: 14,
          ),
        ),
      ),
    );
  }
}

class _ClaimButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool disableAnimations;

  const _ClaimButton({
    required this.label,
    required this.onPressed,
    required this.disableAnimations,
  });

  @override
  State<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<_ClaimButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
    lowerBound: 1,
    upperBound: 1.03,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.disableAnimations) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ClaimButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _offerPurple,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(widget.label, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

class _MarigoldGarland extends StatelessWidget {
  const _MarigoldGarland();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: double.infinity,
      child: CustomPaint(
        painter: _GarlandPainter(),
      ),
    );
  }
}

class _GarlandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var x = 10.0, index = 0; x < size.width; x += 20, index++) {
      paint.color = index.isEven ? _offerSaffron : _offerGold;
      canvas.drawCircle(Offset(x, 9), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
