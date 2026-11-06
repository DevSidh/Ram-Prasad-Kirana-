import 'package:flutter/material.dart';
import '../models/admin_models.dart';
import '../models/stock_summary.dart';
import '../core/billing_strings.dart';
import 'billing_localized_widgets.dart';
import 'product_thumbnail.dart';

class ReadableProductCard extends StatelessWidget {
  const ReadableProductCard(
      {super.key,
      required this.product,
      required this.onEdit,
      required this.onAddStock,
      required this.onSetActive});
  final AdminProduct product;
  final VoidCallback onEdit, onAddStock, onSetActive;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProductThumbnail(imageUrl: product.imageUrl ?? '', size: 64),
              const SizedBox(width: 16),
              Expanded(
                  child: BillingText(product.name,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 12),
            BillingText('${product.categoryName} · ${product.sku}'),
            if (product.brand?.isNotEmpty == true) BillingText(product.brand!),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 10, children: [
              BillingText('Rs. ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              if (product.originalPrice != null &&
                  product.originalPrice! > product.price)
                BillingText('Rs. ${product.originalPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough)),
              BillingText(product.isActive ? 'Active' : 'Inactive'),
            ]),
            const SizedBox(height: 12),
            BillingText(
                'Available: ${product.availableStockLabel} ${BillingStrings.tr(StockSummary.stockUnit(product.unitLabel))}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                  onPressed: onAddStock,
                  icon: const Icon(Icons.add),
                  label: const BillingText('Add stock')),
              OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const BillingText('Edit')),
              OutlinedButton.icon(
                  onPressed: onSetActive,
                  icon: Icon(product.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  label: BillingText(product.isActive
                      ? 'Deactivate product'
                      : 'Activate product')),
            ]),
          ])));
}
