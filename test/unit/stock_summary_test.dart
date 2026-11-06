import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/models/stock_summary.dart';

PosProduct product(String id, String unit, int stock) => PosProduct(
    id: id,
    name: id,
    sku: id,
    barcode: null,
    price: 10,
    unitLabel: unit,
    available: stock);

void main() {
  test(
      'summary keeps weight, pieces and pack sizes separate with no double counting',
      () {
    final result = StockSummary.fromProducts([
      product('rice', '1 kg', 1250),
      product('flour', '500 g', 2250),
      product('soap', '1 pc', 5),
      product('water', '1 L', 3),
      product('juice', '250 ml', 4),
      product('water', '1 L', 3),
      product('gone', '1 pc', -2),
    ]);
    expect(result.productCount, 6);
    expect(result.quantities['Kilograms'], 3.5);
    expect(result.quantities['Pieces'], 5);
    expect(result.quantities['Packs (1 L)'], 3);
    expect(result.quantities['Packs (250 ml)'], 4);
    expect(result.quantities['Liters in sealed packs'], 4);
    expect(StockSummary.availableLabel(product('rice', '1 kg', 1250)),
        '1.25 Kilograms');
    expect(StockSummary.availableLabel(product('water', '1 L', 3)),
        '3 Packs (1 L)');
  });
  test('sale, return and adjustment projections recompute without stale totals',
      () {
    expect(StockSummary.isLooseWeight(product('wholesale-rice', '25 kg', 8)),
        false);
    expect(
        StockSummary.isLooseWeight(product('loose-rice', '1 kg', 8000)), true);
    expect(
        StockSummary.fromProducts([product('wholesale-rice', '25 kg', 8)])
            .quantities['Packs (25 kg)'],
        8);
    expect(
        StockSummary.fromProducts([product('rice', '1 kg', 1200)])
            .quantities['Kilograms'],
        1.2);
    expect(
        StockSummary.fromProducts([product('rice', '1 kg', 950)])
            .quantities['Kilograms'],
        0.95);
    expect(
        StockSummary.fromProducts([product('rice', '1 kg', 1100)])
            .quantities['Kilograms'],
        1.1);
    expect(
        StockSummary.fromProducts([product('rice', '1 kg', 2100)])
            .quantities['Kilograms'],
        2.1);
    expect(StockSummary.fromProducts([]).productCount, 0);
  });
}
