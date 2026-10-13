import 'product.dart';

class CartItem {
  final Product product;
  final bool isWholesale;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false,
  });

  double get unitPrice => isWholesale
      ? product.wholesalePrice ?? product.price
      : product.price;

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'product': product.toJson(),
      'quantity': quantity,
      'isWholesale': isWholesale,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
      isWholesale: json['isWholesale'] as bool? ?? false,
    );
  }
}
