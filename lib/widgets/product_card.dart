import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../core/constants.dart';
import 'product_quick_view.dart';
import 'product_thumbnail.dart';
import 'cart_flight_overlay.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  void _addToCart() {
    final product = widget.product;
    final imageContext = _imageKey.currentContext;
    final imageBox = imageContext?.findRenderObject();
    final sourceRect = imageBox is RenderBox && imageBox.hasSize
        ? imageBox.localToGlobal(Offset.zero) & imageBox.size
        : null;
    final targetKey = CartFlightTarget.maybeOf(context);

    context.read<CartProvider>().addItem(product);
    animateProductToCart(
      context: context,
      product: product,
      sourceRect: sourceRect,
      targetKey: targetKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartProvider = context.read<CartProvider>();
    final productProvider = context.read<ProductProvider>();
    final cartItem = context.select<CartProvider, CartItem?>(
      (provider) => provider.itemForProduct(product.id),
    );
    final isWishlisted = context.select<ProductProvider, bool>(
      (provider) => provider.isWishlisted(product.id),
    );

    return InkWell(
      onTap: () => showProductQuickView(
        context,
        product,
        cartTargetKey: CartFlightTarget.maybeOf(context),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Slot with Badges & Wishlist Heart
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: 1.45,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ProductThumbnail(
                        key: _imageKey,
                        imageUrl: product.imageUrl,
                        size: constraints.maxWidth,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                        fallbackIcon: _productIllustration(product),
                      ),
                    ),
                  ),
                ),
                // Wishlist Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.86),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: isWishlisted
                          ? 'Remove from saved items'
                          : 'Save item',
                      constraints:
                          const BoxConstraints.tightFor(width: 44, height: 44),
                      onPressed: () =>
                          productProvider.toggleWishlist(product.id),
                      icon: Icon(
                        isWishlisted
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isWishlisted
                            ? AppConstants.primary
                            : AppConstants.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.weight,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toString(),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        ' (${product.reviewCount})',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price and Add/Stepper button
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.currencySymbol}${product.price.toInt()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppConstants.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Add Button or Stepper
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: cartItem == null && product.stock > 0
                            ? InkWell(
                                key: const ValueKey('add-to-basket'),
                                onTap: _addToCart,
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add,
                                              color: AppConstants
                                                  .primaryForeground,
                                              size: 14),
                                          SizedBox(width: 2),
                                          Text(
                                            'Add',
                                            style: TextStyle(
                                              color: AppConstants
                                                  .primaryForeground,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : cartItem == null
                                ? Text(
                                    'Unavailable',
                                    key: const ValueKey('unavailable'),
                                    style: TextStyle(
                                      color: AppConstants.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('basket-quantity'),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            cartProvider.updateQuantity(
                                                product.id,
                                                cartItem.quantity - 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(Icons.remove,
                                              size: 14,
                                              color: AppConstants.primaryDark),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          '${cartItem.quantity}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppConstants.primaryDark),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            cartProvider.updateQuantity(
                                                product.id,
                                                cartItem.quantity + 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(Icons.add,
                                              size: 14,
                                              color: AppConstants.primaryDark),
                                        ),
                                      ),
                                    ],
                                  ),
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
    );
  }

  IconData _productIllustration(Product product) {
    final category =
        '${product.categoryName ?? ''} ${product.name}'.toLowerCase();
    if (category.contains('fruit') || category.contains('apple')) {
      return Icons.local_florist_outlined;
    }
    if (category.contains('dairy') ||
        category.contains('milk') ||
        category.contains('egg')) {
      return Icons.egg_alt_outlined;
    }
    if (category.contains('bakery') || category.contains('bread')) {
      return Icons.bakery_dining_outlined;
    }
    if (category.contains('drink') || category.contains('beverage')) {
      return Icons.local_drink_outlined;
    }
    if (category.contains('vegetable') || category.contains('organic')) {
      return Icons.eco_outlined;
    }
    return Icons.shopping_basket_outlined;
  }
}
