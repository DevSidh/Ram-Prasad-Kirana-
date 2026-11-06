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
                style: style, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]);
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
