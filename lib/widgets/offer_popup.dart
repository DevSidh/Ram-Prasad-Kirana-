import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/store_offer.dart';
import 'store_animation.dart';

const _offerSaffron = Color(0xFFE8812A);
const _offerInk = Color(0xFF2D1A52);
const _offerPurple = Color(0xFF6B45AD);

class OfferPopup extends StatelessWidget {
  final StoreOffer offer;

  const OfferPopup({super.key, required this.offer});

  static Future<bool?> show(BuildContext context, StoreOffer offer) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close festival offer',
      barrierColor: const Color(0xAD140822),
      transitionDuration: const Duration(milliseconds: 450),
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
    final heroHeight = (screenHeight * .31).clamp(130.0, 220.0).toDouble();
    final saleBannerWidth = (screenHeight * .24).clamp(150.0, 205.0).toDouble();
    final saleBannerHeight = saleBannerWidth * (120 / 145);
    final diyaSize = (screenHeight * .13).clamp(66.0, 92.0).toDouble();
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
                screenHeight * .88,
              );
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 340,
                  maxHeight: constraints.maxHeight,
                ),
                child: SizedBox(
                  height: dialogHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x73000000),
                            blurRadius: 60,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: heroHeight,
                                  child: Image.asset(
                                    'assets/images/diwali_popup_hero.jpg',
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    errorBuilder: (_, error, stackTrace) {
                                      debugPrint(
                                        'Could not load Diwali rangoli artwork: $error',
                                      );
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  key: const ValueKey('diwali-sale-banner'),
                                  width: saleBannerWidth,
                                  height: saleBannerHeight,
                                  child: Center(
                                    child: StoreAnimation(
                                      assetPath: 'animations/diwali_text.lottie',
                                      size: saleBannerHeight,
                                      semanticLabel:
                                          'Animated Happy Diwali greeting',
                                      loop: true,
                                    ),
                                  ),
                                ),
                                OfferMiddle(
                                  offer: offer,
                                  onClaim: () =>
                                      Navigator.of(context).pop(true),
                                  onMaybeLater: () =>
                                      Navigator.of(context).pop(false),
                                  disableAnimations: disableAnimations,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                  child: Text(
                                    offer.discountType ==
                                            OfferDiscountType.percentage
                                        ? 'Maximum discount Rs. ${offer.maxDiscount}. Valid during Diwali.'
                                        : offer.minOrderAmount > 0
                                            ? 'Save Rs. ${offer.amount} on orders over Rs. ${offer.minOrderAmount}.'
                                            : 'Save Rs. ${offer.amount} with this Diwali offer.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF6A5A8A),
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  height: diyaSize,
                                  child: Image.asset(
                                    'assets/images/diwali_popup_diya.gif',
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, error, stackTrace) {
                                      debugPrint(
                                        'Could not load Diwali diya animation: $error',
                                      );
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
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
    final isPercentage = offer.discountType == OfferDiscountType.percentage;
    final headline = isPercentage ? '${offer.percent}%' : 'Rs. ${offer.amount}';
    final benefitDescription = isPercentage
        ? 'up to Rs. ${offer.maxDiscount}'
        : offer.minOrderAmount > 0
            ? 'off orders over Rs. ${offer.minOrderAmount}'
            : 'off your order';
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                        fontSize: 58,
                        height: .98,
                        fontWeight: FontWeight.w800,
                        color: _offerPurple,
                        letterSpacing: -2,
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 7,
                      ),
                      child: Text(
                        'OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _offerSaffron,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    benefitDescription,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF2A1240),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
              label: 'Claim offer',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
