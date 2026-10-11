import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_thumbnail.dart';

class CartFlightTarget extends InheritedWidget {
  final GlobalKey targetKey;

  const CartFlightTarget({
    super.key,
    required this.targetKey,
    required super.child,
  });

  static GlobalKey? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CartFlightTarget>()?.targetKey;

  @override
  bool updateShouldNotify(CartFlightTarget oldWidget) =>
      targetKey != oldWidget.targetKey;
}

void animateProductToCart({
  required BuildContext context,
  required Product product,
  required Rect? sourceRect,
  required GlobalKey? targetKey,
}) {
  if (sourceRect == null || targetKey?.currentContext == null) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final overlayBox = overlay?.context.findRenderObject();
  final targetBox = targetKey!.currentContext!.findRenderObject();
  if (overlay == null ||
      overlayBox is! RenderBox ||
      targetBox is! RenderBox ||
      !overlayBox.hasSize ||
      !targetBox.hasSize) {
    return;
  }

  final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
  final start = sourceRect.shift(-overlayOrigin);
  final target = targetBox.localToGlobal(
    targetBox.size.center(Offset.zero),
  );
  final endCenter = target - overlayOrigin;
  final end = Rect.fromCenter(center: endCenter, width: 26, height: 26);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ProductFlight(
      product: product,
      start: start,
      end: end,
      onComplete: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _ProductFlight extends StatefulWidget {
  final Product product;
  final Rect start;
  final Rect end;
  final VoidCallback onComplete;

  const _ProductFlight({
    required this.product,
    required this.start,
    required this.end,
    required this.onComplete,
  });

  @override
  State<_ProductFlight> createState() => _ProductFlightState();
}

class _ProductFlightState extends State<_ProductFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
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
      builder: (context, _) {
        final progress = Curves.easeInOutCubic.transform(_controller.value);
        final rect = Rect.lerp(widget.start, widget.end, progress)!;
        final lift = math.sin(progress * math.pi) * 72;
        final opacity =
            (1 - ((progress - 0.78) / 0.22).clamp(0.0, 1.0)).toDouble();
        return Positioned(
          left: rect.left,
          top: rect.top - lift,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: 0.16 * progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x550D3D2B),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ProductThumbnail(
                      imageUrl: widget.product.imageUrl,
                      size: rect.width,
                      width: rect.width,
                      height: rect.height,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
