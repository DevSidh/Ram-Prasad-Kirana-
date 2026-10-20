import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:flutter/material.dart';

class StoreAnimation extends StatefulWidget {
  final String assetPath;
  final double size;
  final double? aspectRatio;
  final String semanticLabel;
  final bool loop;

  const StoreAnimation({
    super.key,
    required this.assetPath,
    required this.size,
    required this.semanticLabel,
    this.aspectRatio,
    this.loop = true,
  }) : assert(aspectRatio == null || aspectRatio > 0);

  @override
  State<StoreAnimation> createState() => _StoreAnimationState();
}

class _StoreAnimationState extends State<StoreAnimation> {
  bool _failedToLoad = false;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = widget.aspectRatio;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox(
        key: ValueKey('store-animation-${widget.assetPath}'),
        width: widget.size,
        height: aspectRatio == null ? widget.size : widget.size / aspectRatio,
        child: _failedToLoad
            ? Icon(
                Icons.animation_outlined,
                size: widget.size * 0.45,
                color: Theme.of(context).colorScheme.error,
              )
            : DotLottieView(
                sourceType: 'asset',
                source: widget.assetPath,
                autoplay: !MediaQuery.disableAnimationsOf(context),
                loop: widget.loop,
                useFrameInterpolation: true,
                fit: BoxFit.contain,
                onLoadError: () {
                  if (mounted) setState(() => _failedToLoad = true);
                },
              ),
      ),
    );
  }
}

class StorePageError extends StatelessWidget {
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const StorePageError({
    super.key,
    this.title = 'Something went wrong',
    this.message =
        'This page could not be displayed. Please go back and try again.',
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StoreAnimation(
                  assetPath: 'animations/error_404.lottie',
                  size: 220,
                  semanticLabel: 'Page error animation',
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (retryLabel != null && onRetry != null) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: onRetry,
                    child: Text(retryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
