import 'package:flutter/material.dart';

class DiwaliLoop extends StatelessWidget {
  static const paymentSuccess = 'assets/animations/payment_success_app.webp';

  final String asset;
  final double? width;
  final double? height;
  final String semanticLabel;
  final bool isPlaying;

  const DiwaliLoop({
    super.key,
    required this.asset,
    required this.semanticLabel,
    this.width,
    this.height,
    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: TickerMode(
          enabled: isPlaying &&
              TickerMode.valuesOf(context).enabled &&
              !MediaQuery.disableAnimationsOf(context),
          child: Image.asset(
            asset,
            width: width,
            height: height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
