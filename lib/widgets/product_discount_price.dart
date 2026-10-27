import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/product.dart';

bool productHasSalePrice(Product product) =>
    !product.isWholesaleItem &&
    product.originalPrice != null &&
    product.originalPrice! > product.price;

int productSalePercent(Product product) {
  if (!productHasSalePrice(product)) return 0;
  return (((product.originalPrice! - product.price) / product.originalPrice!) *
          100)
      .round()
      .clamp(1, 100)
      .toInt();
}

class ProductDiscountBadge extends StatelessWidget {
  const ProductDiscountBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (!productHasSalePrice(product)) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${productSalePercent(product)}% OFF',
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class ProductDiscountPrice extends StatelessWidget {
  const ProductDiscountPrice({
    super.key,
    required this.product,
    required this.currentPrice,
    required this.currentPriceStyle,
    this.previousPriceStyle,
    this.savingsStyle,
    this.showSavings = false,
    this.showBadge = true,
  });

  final Product product;
  final double currentPrice;
  final TextStyle currentPriceStyle;
  final TextStyle? previousPriceStyle;
  final TextStyle? savingsStyle;
  final bool showSavings;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final discounted = productHasSalePrice(product);
    final previousPriceStyle = this.previousPriceStyle ??
        currentPriceStyle.copyWith(
          fontSize: (currentPriceStyle.fontSize ?? 16) * .62,
          color: Colors.black54,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.lineThrough,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discounted)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${AppConstants.currencySymbol}${product.originalPrice!.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: previousPriceStyle,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: 7),
                ProductDiscountBadge(product: product),
              ],
            ],
          ),
        Text(
          '${AppConstants.currencySymbol}${currentPrice.toStringAsFixed(0)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: currentPriceStyle,
        ),
        if (discounted && showSavings)
          Text(
            'You save ${AppConstants.currencySymbol}${(product.originalPrice! - product.price).toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: savingsStyle ??
                currentPriceStyle.copyWith(
                  fontSize: (currentPriceStyle.fontSize ?? 16) * .55,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}
