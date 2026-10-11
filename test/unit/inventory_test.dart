import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/product.dart';

void main() {
  group('Inventory and Product Model Tests', () {
    test('Product stock boundary and serialization', () {
      final product = Product(
        id: 'p-101',
        name: 'A2 Milk',
        price: 150.0,
        originalPrice: 180.0,
        discountPercent: 16,
        weight: '1 L',
        stock: 12,
        description: 'Pure organic A2 milk',
        imageUrl: 'https://example.com/milk.jpg',
        categoryId: 'dairy',
        isOrganic: true,
      );

      expect(product.stock, 12);
      expect(product.isOrganic, true);
      expect(product.discountPercent, 16);

      final json = product.toJson();
      final reconstituted = Product.fromJson(json);

      expect(reconstituted.id, product.id);
      expect(reconstituted.price, product.price);
      expect(reconstituted.stock, product.stock);
    });
  });
}
