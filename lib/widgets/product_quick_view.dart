import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../screens/product/product_details_screen.dart';
import 'cart_flight_overlay.dart';
import 'frosted_panel.dart';
import 'product_thumbnail.dart';

Future<void> showProductQuickView(
  BuildContext context,
  Product product, {
  GlobalKey? cartTargetKey,
}) async {
  final previewImageKey = GlobalKey();
  final openDetails = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB3133025),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 240),
      reverseDuration: Duration(milliseconds: 240),
    ),
    builder: (sheetContext) {
      final cartProvider = context.read<CartProvider>();

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: FrostedPanel(
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            opacity: 0.9,
            blur: 22,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    heightFactor: 1,
                    child: IconButton(
                      tooltip: 'Close product preview',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: LayoutBuilder(
                          builder: (context, constraints) => ProductThumbnail(
                            key: previewImageKey,
                            imageUrl: product.imageUrl,
                            size: constraints.maxWidth,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.zero,
                            fallbackIcon: Icons.local_grocery_store_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.categoryName ??
                                    product.brand ??
                                    'Store pick',
                                style: TextStyle(
                                  color: AppConstants.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.star_rounded,
                              color: AppConstants.primary,
                              size: 17,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${product.rating.toStringAsFixed(1)}  ·  ${product.reviewCount} reviews',
                              style: TextStyle(
                                color: AppConstants.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          product.name,
                          style: TextStyle(
                            color: AppConstants.textDark,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.weight,
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            product.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 17),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${AppConstants.currencySymbol}${product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: AppConstants.primaryDark,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Consumer<ProductProvider>(
                              builder: (context, provider, _) {
                                final isSaved =
                                    provider.isWishlisted(product.id);
                                return OutlinedButton.icon(
                                  onPressed: () =>
                                      provider.toggleWishlist(product.id),
                                  icon: Icon(
                                    isSaved
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: AppConstants.primary,
                                  ),
                                  label: Text(isSaved ? 'Saved' : 'Save'),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, true),
                                child: const Text('Details'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: product.stock > 0
                                    ? () {
                                        final imageBox = previewImageKey
                                            .currentContext
                                            ?.findRenderObject();
                                        final sourceRect =
                                            imageBox is RenderBox &&
                                                    imageBox.hasSize
                                                ? imageBox.localToGlobal(
                                                      Offset.zero,
                                                    ) &
                                                    imageBox.size
                                                : null;
                                        cartProvider.addItem(product);
                                        animateProductToCart(
                                          context: sheetContext,
                                          product: product,
                                          sourceRect: sourceRect,
                                          targetKey: cartTargetKey,
                                        );
                                        Navigator.pop(sheetContext);
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '${product.name} added to your basket'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                      }
                                    : null,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(product.stock > 0
                                    ? 'Add to basket'
                                    : 'Out of stock'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  if (openDetails == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }
}
