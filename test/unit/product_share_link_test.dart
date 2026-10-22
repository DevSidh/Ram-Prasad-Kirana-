import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/product_share_link.dart';

void main() {
  test('share link routes a product and includes the APK fallback', () {
    final link = buildProductShareLink('product-123');

    expect(link, contains('intent://product/product-123'));
    expect(link, contains('scheme=faststore'));
    expect(link, contains('package=com.freshharvest.grocery_app'));
    expect(
      link,
      contains(Uri.encodeComponent(productShareApkUrl)),
    );
  });

  test('shared product routes resolve custom schemes and Flutter paths', () {
    expect(
      sharedProductIdFromRoute('faststore://product/product-123'),
      'product-123',
    );
    expect(sharedProductIdFromRoute('/product/product-123'), 'product-123');
    expect(sharedProductIdFromRoute('/home'), isNull);
    expect(sharedProductIdFromRoute(null), isNull);
  });
}
