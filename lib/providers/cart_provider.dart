import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};
  CartItem? itemForProduct(String productId) => _items[productId];
  List<CartItem> get itemList => _items.values.toList();
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => (subtotal >= 1000.0 || _items.isEmpty) ? 0.0 : 50.0;

  double get grandTotal {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee;
  }

  String _itemKey(String productId, bool isWholesale) =>
      isWholesale ? '$productId:wholesale' : productId;

  void addItem(
    Product product, [
    int quantity = 1,
    bool isWholesale = false,
  ]) {
    if (isWholesale &&
        (!product.isWholesale || product.wholesalePrice == null)) {
      throw StateError('Wholesale pricing is not available for this product.');
    }
    final key = _itemKey(product.id, isWholesale);
    if (_items.containsKey(key)) {
      final current = _items[key]!;
      final minimumQuantity =
          isWholesale ? product.wholesaleMinimumQuantity : 1;
      if (product.stock < minimumQuantity) {
        throw StateError(
            'There is not enough stock for the wholesale minimum.');
      }
      final newQty =
          (current.quantity + quantity).clamp(minimumQuantity, product.stock);
      _items[key] = CartItem(
        product: product,
        quantity: newQty,
        isWholesale: isWholesale,
      );
    } else {
      final minimumQuantity =
          isWholesale ? product.wholesaleMinimumQuantity : 1;
      if (product.stock < minimumQuantity) {
        throw StateError(
            'There is not enough stock for the wholesale minimum.');
      }
      _items[key] = CartItem(
        product: product,
        quantity: quantity.clamp(minimumQuantity, product.stock),
        isWholesale: isWholesale,
      );
    }
    notifyListeners();
  }

  void updateQuantity(
    String productId,
    int quantity, {
    bool isWholesale = false,
  }) {
    final key = _itemKey(productId, isWholesale);
    if (!_items.containsKey(key)) return;
    if (quantity <= 0) {
      removeItem(productId, isWholesale: isWholesale);
      return;
    }
    final item = _items[key]!;
    final minimumQuantity =
        isWholesale ? item.product.wholesaleMinimumQuantity : 1;
    _items[key] = CartItem(
      product: item.product,
      quantity: quantity.clamp(minimumQuantity, item.product.stock),
      isWholesale: isWholesale,
    );
    notifyListeners();
  }

  void removeItem(String productId, {bool isWholesale = false}) {
    _items.remove(_itemKey(productId, isWholesale));
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
