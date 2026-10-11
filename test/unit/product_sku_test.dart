import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/product_sku.dart';

void main() {
  test('generates a readable unique internal store SKU', () {
    final sku = generateStoreSku(
      categorySlug: 'pantry-goods',
      productName: 'Masoor Dal 1kg',
      uniqueValue: 123456,
    );

    expect(sku, 'RPG-PANTRY-MASOOR-DAL-1KG-2N9C');
    expect(RegExp(r'^[A-Z0-9]+(?:-[A-Z0-9]+)*$').hasMatch(sku), isTrue);
  });

  test('uses safe fallback codes for empty category and product names', () {
    expect(
      generateStoreSku(
        categorySlug: '',
        productName: '',
        uniqueValue: 1,
      ),
      'RPG-ITEM-ITEM-1',
    );
  });
}
