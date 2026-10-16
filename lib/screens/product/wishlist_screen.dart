import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/store_animation.dart';
import '../category/categories_screen.dart';
import '../../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final provider = context.watch<ProductProvider>();
    final products = provider.wishlistProducts;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Your wishlist'),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: products.isEmpty
          ? provider.loadingWishlist
              ? const Center(child: CircularProgressIndicator())
              : provider.wishlistErrorMessage != null
                  ? StorePageError(
                      title: 'Wishlist unavailable',
                      message: provider.wishlistErrorMessage!,
                      retryLabel: 'Retry',
                      onRetry: provider.refreshWishlist,
                    )
                  : Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      color: AppConstants.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Save the things you love',
                      style: TextStyle(
                        color: AppConstants.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the heart on any product to keep it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppConstants.textMuted),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoriesScreen(),
                        ),
                      ),
                      child: const Text('Browse the store'),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: responsiveGridCrossAxisCount(
                    availableWidth: constraints.maxWidth,
                    horizontalPadding: 32,
                    minTileWidth: 160,
                  ),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    ProductCard(product: products[index]),
              ),
            ),
    );
  }
}
