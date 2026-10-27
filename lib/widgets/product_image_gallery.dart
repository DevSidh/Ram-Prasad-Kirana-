import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/product.dart';
import 'product_thumbnail.dart';

/// A shared product image gallery for the quick view and full details screen.
class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.product,
    required this.height,
    this.borderRadius = BorderRadius.zero,
    this.mainImageKey,
  });

  final Product product;
  final double height;
  final BorderRadius borderRadius;
  final GlobalKey? mainImageKey;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery>
    with WidgetsBindingObserver {
  static const _autoAdvanceDelay = Duration(seconds: 4);
  static const _transitionDuration = Duration(milliseconds: 420);

  late final PageController _pageController;
  Timer? _autoAdvanceTimer;
  late final List<String> _images;
  int _currentIndex = 0;
  bool _reduceMotion = false;
  bool _appIsResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _images = <String>{
      if (widget.product.imageUrl.trim().isNotEmpty)
        widget.product.imageUrl.trim(),
      ...widget.product.imageUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty),
    }.toList(growable: false);
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _startAutoAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsResumed = state == AppLifecycleState.resumed;
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_images.length < 2 || _reduceMotion || !_appIsResumed || !mounted) {
      return;
    }
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % _images.length;
      _pageController
          .animateToPage(
            nextIndex,
            duration: _transitionDuration,
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(_startAutoAdvance);
    });
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index && mounted) {
      setState(() => _currentIndex = index);
    }
    _startAutoAdvance();
  }

  void _showImage(int index) {
    _autoAdvanceTimer?.cancel();
    if (index == _currentIndex) {
      _startAutoAdvance();
      return;
    }
    if (_reduceMotion) {
      _pageController.jumpToPage(index);
      _startAutoAdvance();
    } else {
      _pageController
          .animateToPage(
            index,
            duration: _transitionDuration,
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(_startAutoAdvance);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAdditionalImages = _images.length > 1;
    final thumbnailHeight = hasAdditionalImages ? 58.0 : 0.0;
    final imageHeight = widget.height - thumbnailHeight;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: AppConstants.surfaceLight,
        child: Column(
          children: [
            SizedBox(
              key: widget.mainImageKey,
              height: imageHeight,
              width: double.infinity,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _images.isEmpty ? 1 : _images.length,
                allowImplicitScrolling: true,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) => ProductThumbnail(
                  imageUrl: _images.isEmpty
                      ? widget.product.imageUrl
                      : _images[index],
                  size: imageHeight,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.zero,
                  fallbackIcon: Icons.shopping_basket_outlined,
                  backgroundColor: Colors.white,
                  imageWidthFactor: 1,
                ),
              ),
            ),
            if (hasAdditionalImages)
              SizedBox(
                height: thumbnailHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Product image ${index + 1} of ${_images.length}',
                      child: InkWell(
                        onTap: () => _showImage(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? AppConstants.primary
                                  : AppConstants.borderLight,
                              width: selected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ProductThumbnail(
                            imageUrl: _images[index],
                            size: 42,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.circular(7),
                            fallbackIcon: Icons.shopping_basket_outlined,
                            backgroundColor: Colors.white,
                            imageWidthFactor: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
