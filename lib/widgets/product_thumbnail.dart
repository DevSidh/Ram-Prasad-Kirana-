import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/media.dart';

class ProductThumbnail extends StatefulWidget {
  final String imageUrl;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;

  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.fallbackIcon = Icons.shopping_basket_outlined,
  });

  @override
  State<ProductThumbnail> createState() => _ProductThumbnailState();
}

class _ProductThumbnailState extends State<ProductThumbnail> {
  static const _maxRetries = 1;
  int _retryCount = 0;

  @override
  void didUpdateWidget(covariant ProductThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryCount = 0;
    }
  }

  void _retryAfterFailure(String failedUrl) {
    if (_retryCount >= _maxRetries) return;
    _retryCount++;
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      try {
        await CachedNetworkImage.evictFromCache(failedUrl);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'product image cache',
            context: ErrorDescription('while clearing a failed thumbnail'),
          ),
        );
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageWidth = widget.width ?? widget.size;
    final imageHeight = widget.height ?? widget.size;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cacheDimension(
          imageWidth,
          constraints.maxWidth,
          pixelRatio,
        );
        final cacheHeight = _cacheDimension(
          imageHeight,
          constraints.maxHeight,
          pixelRatio,
        );
        final url = optimizedProductImageUrl(
          widget.imageUrl,
          targetWidth: cacheWidth,
        );
        final fallback = Container(
          width: imageWidth,
          height: imageHeight,
          color: AppConstants.primaryLight,
          alignment: Alignment.center,
          child: Icon(
            widget.fallbackIcon,
            color: AppConstants.primary,
            size: widget.size >= 80 ? 46 : 26,
          ),
        );
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: url.isEmpty
              ? fallback
              : ColoredBox(
                  color: AppConstants.surfaceLight,
                  child: CachedNetworkImage(
                    key: ValueKey('$url-$_retryCount'),
                    imageUrl: url,
                    imageRenderMethodForWeb: kIsWeb
                        ? ImageRenderMethodForWeb.HttpGet
                        : ImageRenderMethodForWeb.HtmlImage,
                    width: imageWidth,
                    height: imageHeight,
                    memCacheWidth: cacheWidth,
                    memCacheHeight: cacheHeight,
                    fit: widget.fit,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, failedUrl, error) {
                      FlutterError.reportError(
                        FlutterErrorDetails(
                          exception: error,
                          library: 'product image',
                          context: ErrorDescription(
                            'while loading a remote product thumbnail',
                          ),
                        ),
                      );
                      _retryAfterFailure(failedUrl);
                      return fallback;
                    },
                  ),
                ),
        );
      },
    );
  }

  int _cacheDimension(double requested, double constraint, double pixelRatio) {
    final logicalDimension = requested.isFinite
        ? requested
        : constraint.isFinite
            ? constraint
            : widget.size.isFinite
                ? widget.size
                : 1.0;
    final safeDimension =
        logicalDimension > 0 && logicalDimension.isFinite ? logicalDimension : 1.0;
    final safePixelRatio =
        pixelRatio > 0 && pixelRatio.isFinite ? pixelRatio : 1.0;
    final scaledDimension = safeDimension * safePixelRatio;

    if (!scaledDimension.isFinite) return 1600;
    return scaledDimension.round().clamp(1, 1600).toInt();
  }
}
