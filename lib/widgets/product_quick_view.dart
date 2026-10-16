import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/widgets/app_widgets.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../providers/product_provider.dart';
import '../screens/product/product_details_screen.dart';
import 'cart_flight_overlay.dart';
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
      duration: Duration(milliseconds: 260),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (sheetContext) {
      final cartProvider = context.read<CartProvider>();
      final theme = Theme.of(sheetContext);
      final tokens = AppThemeExtension.of(sheetContext);
      final addedToBasketLabel = sheetContext.tr('added to your basket');
      var quantity = 1;

      return DraggableScrollableSheet(
        initialChildSize: .78,
        minChildSize: .56,
        maxChildSize: .94,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: tokens.surfaceGlass,
              child: StatefulBuilder(
                builder: (context, setSheetState) => Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 12, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        width: 38,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: tokens.textSecondary
                                              .withValues(alpha: .45),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        context.tr('Close product preview'),
                                    onPressed: () =>
                                        Navigator.pop(sheetContext),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: SizedBox(
                                    height: 210,
                                    width: double.infinity,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          ProductThumbnail(
                                        key: previewImageKey,
                                        imageUrl: product.imageUrl,
                                        size: constraints.maxWidth,
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        fit: BoxFit.contain,
                                        borderRadius: BorderRadius.zero,
                                        fallbackIcon:
                                            Icons.local_grocery_store_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate(
                                [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          context
                                              .tr(
                                                product.categoryName ??
                                                    product.brand ??
                                                    'Store pick',
                                              )
                                              .toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: .7,
                                          ),
                                        ),
                                      ),
                                      if (product.reviewCount > 0) ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFE2A83B),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${product.rating.toStringAsFixed(1)} · ${product.reviewCount}',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    product.name,
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.weight,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  if (product.description.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      product.description,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: tokens.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${AppConstants.currencySymbol}${product.price.toStringAsFixed(0)}',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      QuantityStepper(
                                        value: quantity,
                                        minimum: 1,
                                        onDecrement: quantity > 1
                                            ? () => setSheetState(
                                                  () => quantity--,
                                                )
                                            : null,
                                        onIncrement: product.stock > quantity
                                            ? () => setSheetState(
                                                  () => quantity++,
                                                )
                                            : null,
                                        decreaseLabel:
                                            context.tr('Decrease quantity'),
                                        increaseLabel:
                                            context.tr('Increase quantity'),
                                        quantityLabel: context.tr('Quantity'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              Navigator.pop(sheetContext, true),
                                          icon: const Icon(
                                            Icons.notes_rounded,
                                            size: 18,
                                          ),
                                          label: Text(context.tr('Details')),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Consumer<ProductProvider>(
                                        builder: (context, provider, _) {
                                          final isSaved =
                                              provider.isWishlisted(product.id);
                                          return IconButton(
                                            tooltip: context.tr(
                                              isSaved
                                                  ? 'Remove from saved items'
                                                  : 'Save item',
                                            ),
                                            onPressed: () async {
                                              try {
                                                await provider.toggleWishlist(
                                                  product.id,
                                                );
                                              } catch (error) {
                                                if (!sheetContext.mounted) {
                                                  return;
                                                }
                                                ScaffoldMessenger.of(
                                                  sheetContext,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      error
                                                          .toString()
                                                          .replaceFirst(
                                                            'Exception: ',
                                                            '',
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: Icon(
                                              isSaved
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: isSaved
                                                  ? theme.colorScheme.error
                                                  : tokens.textSecondary,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                        child: PrimaryButton(
                          label: product.stock > 0
                              ? '${context.tr('Add to basket')} · ${AppConstants.currencySymbol}${(product.price * quantity).toStringAsFixed(0)}'
                              : context.tr('Out of stock'),
                          icon: Icons.add_shopping_cart_rounded,
                          onPressed: product.stock > 0
                              ? () {
                                  final imageBox = previewImageKey
                                      .currentContext
                                      ?.findRenderObject();
                                  final sourceRect = imageBox is RenderBox &&
                                          imageBox.hasSize
                                      ? imageBox.localToGlobal(Offset.zero) &
                                          imageBox.size
                                      : null;
                                  cartProvider.addItem(product, quantity);
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
                                          '${product.name} $addedToBasketLabel',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                }
                              : null,
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ),
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
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }
}
