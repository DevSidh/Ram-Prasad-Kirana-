import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_thumbnail.dart';

class WholesaleScreen extends StatefulWidget {
  const WholesaleScreen({super.key});

  @override
  State<WholesaleScreen> createState() => _WholesaleScreenState();
}

class _WholesaleScreenState extends State<WholesaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final query = _query.toLowerCase();
    final products = catalog.allProducts.where((product) {
      if (!product.isWholesale) return false;
      return query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.brand?.toLowerCase().contains(query) ?? false) ||
          (product.categoryName?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Wholesale'),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123F32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock up. Save on bulk.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Bulk prices and minimum quantities are shown on each item. Checkout and delivery work as usual.',
                        style: TextStyle(
                          color: Color(0xFFD2E9DC),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search wholesale products',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppConstants.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: AppConstants.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: AppConstants.borderLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: catalog.isLoading && catalog.allProducts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                catalog.errorMessage == null
                                    ? Icons.inventory_2_outlined
                                    : Icons.cloud_off_outlined,
                                size: 42,
                                color: AppConstants.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                catalog.errorMessage ??
                                    (_query.isEmpty
                                        ? 'Wholesale products will appear here when the store adds them.'
                                        : 'No wholesale products match "$_query".'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppConstants.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              if (catalog.errorMessage != null)
                                TextButton(
                                  onPressed: catalog.loadCatalog,
                                  child: const Text('Try again'),
                                ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: products.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) => _WholesaleProductCard(
                          product: products[index],
                          cartQuantity:
                              cart.items['${products[index].id}:wholesale']
                                      ?.quantity ??
                                  0,
                          onAdd: () {
                            final product = products[index];
                            final minimum =
                                product.wholesaleMinimumQuantity;
                            try {
                              cart.addItem(product, minimum, true);
                            } on StateError catch (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error.message.toString()),
                                ),
                              );
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _WholesaleProductCard extends StatelessWidget {
  final Product product;
  final int cartQuantity;
  final VoidCallback onAdd;

  const _WholesaleProductCard({
    required this.product,
    required this.cartQuantity,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final unitPrice = product.wholesalePrice ?? product.price;
    final minimum = product.wholesaleMinimumQuantity;
    final outOfStock = product.stock < minimum;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Row(
        children: [
          ProductThumbnail(
            imageUrl: product.imageUrl,
            size: 82,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.brand?.isNotEmpty == true)
                  Text(
                    product.brand!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Minimum $minimum × ${product.weight} · ${product.stock} available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: AppConstants.textMuted, fontSize: 10),
                ),
                const SizedBox(height: 7),
                Text(
                  'Rs. ${unitPrice.toStringAsFixed(0)} / unit',
                  style: const TextStyle(
                    color: AppConstants.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 88,
            child: FilledButton(
              onPressed: outOfStock ? null : onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
              ),
              child: Text(
                cartQuantity > 0
                    ? '$cartQuantity in basket'
                    : outOfStock
                        ? 'Unavailable'
                        : 'Add $minimum',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
