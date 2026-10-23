import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/product.dart';

void main() {
  test('product gallery URLs are parsed and serialized', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'name': 'Tea',
      'categoryId': 'category-1',
      'price': 125,
      'unitLabel': '1 pack',
      'stock': 4,
      'description': '',
      'imageUrl': 'https://example.test/cover.jpg',
      'imageUrls': [
        'https://example.test/side.jpg',
        null,
        'https://example.test/back.jpg',
      ],
    });

    expect(product.imageUrls, [
      'https://example.test/side.jpg',
      'https://example.test/back.jpg',
    ]);
    expect(product.toJson()['imageUrls'], product.imageUrls);
  });
}
