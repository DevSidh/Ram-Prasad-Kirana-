import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  double _tip = 40.0;

  Map<String, CartItem> get items => {..._items};
  List<CartItem> get itemList => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get tip => _tip;

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => (subtotal >= 1000.0 || _items.isEmpty) ? 0.0 : 50.0;

  double get grandTotal {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + _tip;
  }

  void addItem(Product product, [int quantity = 1]) {
    if (_items.containsKey(product.id)) {
      final current = _items[product.id]!;
      final newQty = (current.quantity + quantity).clamp(1, product.stock);
      _items[product.id] = CartItem(product: product, quantity: newQty);
    } else {
      _items[product.id] = CartItem(
        product: product,
        quantity: quantity.clamp(1, product.stock),
      );
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final item = _items[productId]!;
    _items[productId] = CartItem(
      product: item.product,
      quantity: quantity.clamp(1, item.product.stock),
    );
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  void setTip(double amount) {
    _tip = amount;
    notifyListeners();
  }

}
