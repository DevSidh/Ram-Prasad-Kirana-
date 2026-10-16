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
      expect(cart.deliveryFee, 40);
      expect(cart.grandTotal, 940);
    });

    test('Removing item clears item from cart', () {
      cart.addItem(sampleApple, 1);
      cart.removeItem(sampleApple.id);
      expect(cart.items.isEmpty, true);
      expect(cart.subtotal, 0.0);
    });

    test('Wholesale minimum can be disabled by using a minimum of one', () {
      final product = Product(
        id: 'wholesale-rice',
        name: 'Wholesale rice',
        price: 150,
        weight: '1 kg',
        stock: 20,
        description: 'Rice sold in bulk',
        imageUrl: '',
        categoryId: 'pantry',
        isWholesale: true,
        wholesalePrice: 125,
        wholesaleMinimumQuantity: 1,
      );

      cart.addItem(product, product.wholesaleMinimumQuantity, true);

      expect(cart.items['wholesale-rice:wholesale']?.quantity, 1);
      expect(cart.subtotal, 125);
    });

    test('Wholesale minimum quantity remains enforced when enabled', () {
      final product = Product(
        id: 'wholesale-oil',
        name: 'Wholesale oil',
        price: 250,
        weight: '1 l',
        stock: 20,
        description: 'Oil sold in bulk',
        imageUrl: '',
        categoryId: 'pantry',
        isWholesale: true,
        wholesalePrice: 220,
        wholesaleMinimumQuantity: 6,
      );

      cart.addItem(product, product.wholesaleMinimumQuantity, true);

      expect(cart.items['wholesale-oil:wholesale']?.quantity, 6);
      expect(cart.subtotal, 1320);
    });

    test('Cart quantity is capped to the backend limit', () {
      cart.addItem(sampleApple, 200);

      expect(cart.itemForProduct(sampleApple.id)?.quantity, 5);
    });

    test('Stale out-of-stock cart items do not throw on quantity update', () {
      cart.addItem(sampleApple, 1);
      final unavailable = Product(
        id: sampleApple.id,
        name: sampleApple.name,
        categoryId: sampleApple.categoryId,
        price: sampleApple.price,
        weight: sampleApple.weight,
        stock: 0,
        description: sampleApple.description,
        imageUrl: sampleApple.imageUrl,
      );
      cart.restoreItem(unavailable, 1);

      expect(() => cart.updateQuantity(sampleApple.id, 2), returnsNormally);
      expect(cart.hasUnavailableItems, isTrue);
      expect(cart.itemForProduct(sampleApple.id)?.quantity, 1);
    });

    test('Restoring removed item replaces instead of doubling quantity', () {
      cart.addItem(sampleApple, 2);
      cart.removeItem(sampleApple.id);
      cart.addItem(sampleApple, 1);

      cart.restoreItem(sampleApple, 2);

      expect(cart.itemForProduct(sampleApple.id)?.quantity, 2);
    });
  });
}
