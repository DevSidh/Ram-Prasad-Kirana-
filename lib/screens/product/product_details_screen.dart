import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/product_thumbnail.dart';
import '../checkout/checkout_screen.dart';
import '../../services/product_share_link.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  static const _shareChannel = MethodChannel('faststore/share');
  int _quantity = 1;
  bool _sharing = false;
  bool _submittingRating = false;
  double? _updatedRating;
  int? _updatedReviewCount;

  @override
  void initState() {
    super.initState();
    if (widget.product.isWholesaleItem) {
      _quantity = widget.product.wholesaleMinimumQuantity;
    }
  }

  Future<void> _shareProduct() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final product = widget.product;
      await _shareChannel.invokeMethod<void>('shareText', {
        'subject': 'FastStore · ${product.name}',
        'text': '${product.name} · '
            '${AppConstants.currencySymbol}${product.price.toStringAsFixed(0)}\n'
            '${buildProductShareLink(product.id)}\n'
            'Get FastStore: $productShareApkUrl',
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not share this product: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _toggleWishlist(ProductProvider provider) async {
    try {
      await provider.toggleWishlist(widget.product.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _rateProduct(
    ProductProvider productProvider,
    bool isAuthenticated,
  ) async {
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to rate this product.')),
      );
      return;
    }

    var selectedRating = 0;
    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rate ${widget.product.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var value = 1; value <= 5; value++)
                      IconButton(
                        tooltip: '$value ${value == 1 ? 'star' : 'stars'}',
                        onPressed: () =>
                            setSheetState(() => selectedRating = value),
                        icon: Icon(
                          value <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFE7A900),
                          size: 34,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedRating == 0
                        ? null
                        : () => Navigator.of(sheetContext).pop(selectedRating),
                    child: const Text('Save rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (rating == null || !mounted) return;
    setState(() => _submittingRating = true);
    try {
      final target = widget.product.isWholesaleItem ? 'wholesale' : 'products';
      final response = await productProvider.apiService.post(
        '/reviews/$target/${Uri.encodeComponent(widget.product.id)}',
        {'rating': rating},
      );
      if (!mounted) return;
      final data = response is Map<String, dynamic> ? response['data'] : null;
      if (data is! Map<String, dynamic> ||
          data['rating'] is! num ||
          data['reviewCount'] is! num) {
        throw const FormatException('The server returned an invalid rating.');
      }
      setState(() {
        _updatedRating = (data['rating'] as num).toDouble();
        _updatedReviewCount = (data['reviewCount'] as num).toInt();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your rating has been saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = context.watch<AuthProvider?>();
    context.watch<ThemeProvider?>();
    final isWishlisted = productProvider.isWishlisted(widget.product.id);
    final rating = _updatedRating ?? widget.product.rating;
    final reviewCount = _updatedReviewCount ?? widget.product.reviewCount;
    final minimumQuantity = widget.product.isWholesaleItem
        ? widget.product.wholesaleMinimumQuantity
        : 1;
    final unavailable = widget.product.stock < minimumQuantity;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundLight,
        actions: widget.product.isWholesaleItem
            ? const []
            : [
                IconButton(
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.red : AppConstants.textDark,
                  ),
                  onPressed: () => _toggleWishlist(productProvider),
                ),
                IconButton(
                  tooltip: 'Share product',
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                  onPressed: _sharing ? null : _shareProduct,
                ),
              ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            Container(
              height: 280,
              width: double.infinity,
              color: AppConstants.surfaceLight,
              child: ProductThumbnail(
                imageUrl: widget.product.imageUrl,
                size: 280,
                width: double.infinity,
                height: 280,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.zero,
                fallbackIcon: Icons.shopping_basket_outlined,
                backgroundColor: Colors.white,
                imageWidthFactor: .77,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Origin
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (widget.product.brand ?? 'Ram Prasad').toUpperCase(),
                        style: const TextStyle(
                          color: AppConstants.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.product.origin != null)
                        Text(
                          widget.product.origin!,
                          style: TextStyle(
                              color: AppConstants.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Product Title
                  Text(
                    widget.product.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rating and reviews
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        reviewCount > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        reviewCount == 0
                            ? ' (no customer ratings yet)'
                            : ' ($reviewCount customer ratings)',
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _submittingRating
                          ? null
                          : () => _rateProduct(
                                productProvider,
                                authProvider?.isAuthenticated ?? false,
                              ),
                      icon: _submittingRating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.star_outline_rounded, size: 18),
                      label: Text(
                        _submittingRating
                            ? 'Saving rating'
                            : 'Rate this product',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing & Packaging Unit Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.currencySymbol}${widget.product.price.toInt()}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textDark,
                              ),
                            ),
                            Text(
                              widget.product.isWholesaleItem
                                  ? 'Wholesale unit · minimum $minimumQuantity'
                                  : 'Standard packaging: ${widget.product.weight}',
                              style: TextStyle(
                                  color: AppConstants.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        // Quantity selector
                        Container(
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppConstants.borderLight),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  if (_quantity > minimumQuantity) {
                                    setState(() => _quantity--);
                                  }
                                },
                              ),
                              Text(
                                '$_quantity',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  if (_quantity < widget.product.stock) {
                                    setState(() => _quantity++);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    widget.product.isWholesaleItem
                        ? 'Product details'
                        : 'About this harvest',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product.description,
                    style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 13,
                        height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  if (!widget.product.isWholesaleItem)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.ac_unit,
                            color: AppConstants.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cold-chain insulated tote packing guarantee with express 45-min delivery.',
                              style: TextStyle(
                                color: AppConstants.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Sticky Bottom Purchase Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.surfaceLight,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: unavailable
                      ? null
                      : () {
                          cartProvider.addItem(
                            widget.product,
                            _quantity,
                            widget.product.isWholesaleItem,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Added $_quantity × ${widget.product.name} to basket'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppConstants.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add to Cart',
                      style: TextStyle(
                          color: AppConstants.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: unavailable
                      ? null
                      : () {
                          cartProvider.addItem(
                            widget.product,
                            _quantity,
                            widget.product.isWholesaleItem,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CheckoutScreen()),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Buy Now',
                      style: TextStyle(
                          color: AppConstants.primaryForeground,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
