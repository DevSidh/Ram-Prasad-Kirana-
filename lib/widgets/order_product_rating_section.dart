import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/cart_item.dart';
import '../providers/product_provider.dart';

/// Lets a customer rate each product on a successfully paid order.
/// The backend stores one rating per customer and product, so submitting a
/// later rating after a repeat purchase updates that customer's rating.
class OrderProductRatingSection extends StatefulWidget {
  final List<CartItem> items;
  final String title;

  const OrderProductRatingSection({
    super.key,
    required this.items,
    this.title = 'Rate your products',
  });

  @override
  State<OrderProductRatingSection> createState() =>
      _OrderProductRatingSectionState();
}

class _OrderProductRatingSectionState extends State<OrderProductRatingSection> {
  final Set<String> _submitting = {};
  final Set<String> _rated = {};

  Future<void> _rateProduct(CartItem item) async {
    final product = item.product;
    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var selected = 0;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rate ${product.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
                        onPressed: () =>
                            setSheetState(() => selected = index + 1),
                        icon: Icon(
                          index < selected ? Icons.star : Icons.star_border,
                          size: 34,
                          color: const Color(0xFFE7A900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected == 0
                          ? null
                          : () => Navigator.of(sheetContext).pop(selected),
                      child: const Text('Submit rating'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (rating == null || !mounted) return;

    final key = '${item.isWholesale ? 'wholesale' : 'products'}:${product.id}';
    setState(() => _submitting.add(key));
    try {
      final target = item.isWholesale ? 'wholesale' : 'products';
      await context.read<ProductProvider>().apiService.post(
        '/reviews/$target/${Uri.encodeComponent(product.id)}',
        {'rating': rating},
      );
      if (!mounted) return;
      setState(() => _rated.add(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your rating for ${product.name} was saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'How was each item? You can update your rating after another purchase.',
            style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < widget.items.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _buildProductRow(widget.items[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildProductRow(CartItem item) {
    final key =
        '${item.isWholesale ? 'wholesale' : 'products'}:${item.product.id}';
    final isSubmitting = _submitting.contains(key);
    final isRated = _rated.contains(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: isSubmitting ? null : () => _rateProduct(item),
            icon: isSubmitting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isRated ? Icons.check_circle_outline : Icons.star_outline,
                    size: 18,
                  ),
            label: Text(isRated ? 'Update rating' : 'Rate'),
          ),
        ],
      ),
    );
  }
}
