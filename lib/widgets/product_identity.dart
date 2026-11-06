import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/offline_pos_store.dart';
import 'billing_localized_widgets.dart';
import 'product_thumbnail.dart';

class ProductIdentity extends StatelessWidget {
  const ProductIdentity(
      {super.key,
      required this.name,
      this.imageUrl,
      this.productId,
      this.sku,
      this.size = 52,
      this.style,
      this.store = const OfflinePosStore()});
  final String name;
  final String? imageUrl, productId, sku;
  final double size;
  final TextStyle? style;
  final OfflinePosStore store;
  @override
  Widget build(BuildContext context) => Row(children: [
        CatalogProductThumbnail(
            imageUrl: imageUrl,
            productId: productId,
            sku: sku,
            size: size,
            store: store),
        const SizedBox(width: 12),
        Expanded(
            child: BillingText(name,
                style: style,
                maxLines: size <= 40 ? 1 : 2,
                overflow: TextOverflow.ellipsis)),
      ]);
}

/// Stable product rows for invoice/refund details. On narrow windows the amount
/// sits below the name instead of squeezing it into a vertical column.
class ProductDetailRow extends StatelessWidget {
  const ProductDetailRow(
      {super.key,
      required this.name,
      required this.subtitle,
      required this.amount,
      this.productId,
      this.sku,
      this.imageUrl,
      this.photoName,
      this.store = const OfflinePosStore()});
  final String name, subtitle, amount;
  final String? productId, sku, imageUrl, photoName;
  final OfflinePosStore store;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 480 ||
              MediaQuery.textScalerOf(context).scale(18) > 25;
          final price = BillingText(amount,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600));
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CatalogProductThumbnail(
                productId: productId,
                sku: sku,
                imageUrl: imageUrl,
                name: photoName ?? name,
                store: store,
                size: 48),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  BillingText(name,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  BillingText(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (stacked) ...[const SizedBox(height: 5), price],
                ])),
            if (!stacked) ...[
              const SizedBox(width: 16),
              ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * .28),
                  child: price),
            ],
          ]);
        }),
      );
}

/// Old bill snapshots keep their original names. Resolve their picture by stable
/// ID/SKU from the local catalogue without changing or uploading the old bill.
class CatalogProductThumbnail extends StatelessWidget {
  const CatalogProductThumbnail(
      {super.key,
      this.productId,
      this.sku,
      this.imageUrl,
      this.name,
      this.size = 48,
      this.store = const OfflinePosStore()});
  final String? productId, sku, imageUrl, name;
  final double size;
  final OfflinePosStore store;
  static final _catalogues =
      Expando<({DateTime at, Future<List<PosProduct>> value})>();
  Future<List<PosProduct>> _catalogue() {
    final old = _catalogues[store];
    if (old != null &&
        DateTime.now().difference(old.at) < const Duration(minutes: 1)) {
      return old.value;
    }
    final value =
        store.readCatalogBaseline().catchError((Object _) => <PosProduct>[]);
    _catalogues[store] = (at: DateTime.now(), value: value);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if ((imageUrl?.isNotEmpty ?? false) ||
        kIsWeb ||
        (productId == null && sku == null && name == null)) {
      return ProductThumbnail(imageUrl: imageUrl ?? '', size: size);
    }
    return FutureBuilder<List<PosProduct>>(
        future: _catalogue(),
        builder: (context, state) {
          final matches = (state.data ?? const <PosProduct>[])
              .where((p) =>
                  (productId != null && p.id == productId) ||
                  (sku?.isNotEmpty == true &&
                      p.sku.toLowerCase() == sku!.toLowerCase()) ||
                  (productId == null &&
                      sku == null &&
                      name?.isNotEmpty == true &&
                      p.name.toLowerCase() == name!.toLowerCase()))
              .toList();
          final match = matches.length == 1 ? matches.single : null;
          return ProductThumbnail(imageUrl: match?.imageUrl ?? '', size: size);
        });
  }
}
