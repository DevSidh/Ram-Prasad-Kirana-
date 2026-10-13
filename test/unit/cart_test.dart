import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';

void main() {
  group('CartProvider Unit Tests', () {
    late CartProvider cart;
    late Product sampleApple;

    setUp(() {
      cart = CartProvider();
      sampleApple = Product(
        id: 'p-apple-1',
        name: 'Mustang Apples',
        price: 300.0,
        weight: '1 kg',
        stock: 5,
        description: 'Fresh apples',
        imageUrl: '',
        categoryId: 'fruits',
      );
    });

    test('Initial cart is empty', () {
      expect(cart.items.isEmpty, true);
      expect(cart.subtotal, 0.0);
      expect(cart.itemCount, 0);
    });

    test('Adding product increases item count and subtotal', () {
      cart.addItem(sampleApple, 2);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 600.0);
    });

    test('Updating quantity respects product stock limits', () {
      cart.addItem(sampleApple, 1);
      // Attempt to exceed stock limit of 5
      cart.updateQuantity(sampleApple.id, 10);
      expect(cart.items[sampleApple.id]?.quantity, 5);
      expect(cart.subtotal, 1500.0);
    });

    test('Totals include only item prices and delivery fee', () {
      cart.addItem(sampleApple, 3); // 3 * 300 = 900
      expect(cart.grandTotal, 900.0 + cart.deliveryFee);
    });

    test('Removing item clears item from cart', () {
      cart.addItem(sampleApple, 1);
      cart.removeItem(sampleApple.id);
      expect(cart.items.isEmpty, true);
      expect(cart.subtotal, 0.0);
    });
  });
}
