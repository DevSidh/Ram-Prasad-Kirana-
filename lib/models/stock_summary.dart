import 'pos_models.dart';

/// Counts base stock units, never adds unlike units or rounds kilograms to pieces.
class StockSummary {
  const StockSummary(this.productCount, this.quantities);
  final int productCount;
  final Map<String, double> quantities;

  factory StockSummary.fromProducts(Iterable<PosProduct> products) {
    final unique = {for (final product in products) product.id: product};
    final totals = <String, int>{};
    for (final product in unique.values) {
      final available = product.available < 0 ? 0 : product.available;
      final group =
          product.id.startsWith('wholesale-') && isWeight(product.unitLabel)
              ? 'Packs (${product.unitLabel.trim()})'
              : stockUnit(product.unitLabel);
      totals.update(group, (value) => value + available,
          ifAbsent: () => available);
      final volume = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(ml|l|liters?|litres?)\s*$',
              caseSensitive: false)
          .firstMatch(product.unitLabel);
      if (volume != null) {
        final millilitres = (double.parse(volume[1]!) *
                (volume[2]!.toLowerCase() == 'ml' ? 1 : 1000))
            .round();
        totals.update('Liters in sealed packs',
            (value) => value + millilitres * available,
            ifAbsent: () => millilitres * available);
      }
    }
    return StockSummary(unique.length, {
      for (final entry in totals.entries)
        entry.key:
            entry.key == 'Kilograms' || entry.key == 'Liters in sealed packs'
                ? entry.value / 1000
                : entry.value.toDouble(),
    });
  }

  static bool isWeight(String label) =>
      RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
          .hasMatch(label);

  static String stockUnit(String label) {
    if (isWeight(label)) return 'Kilograms';
    final clean = label.trim();
    if (RegExp(r'^(?:1\s*)?(?:pcs?|pieces?|units?)$', caseSensitive: false)
        .hasMatch(clean)) {
      return 'Pieces';
    }
    // In this database volume labels describe a sealed pack size. Stock is
    // a count of those packs, not millilitres. Keep each size separate.
    return 'Packs ($clean)';
  }

  static bool isLooseWeight(PosProduct product) =>
      !product.id.startsWith('wholesale-') && isWeight(product.unitLabel);

  static String quantity(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  static String availableLabel(PosProduct product) =>
      '${quantity(isWeight(product.unitLabel) && !product.id.startsWith('wholesale-') ? product.available / 1000 : product.available.toDouble())} ${product.id.startsWith('wholesale-') && isWeight(product.unitLabel) ? 'Packs (${product.unitLabel.trim()})' : stockUnit(product.unitLabel)}';
}
