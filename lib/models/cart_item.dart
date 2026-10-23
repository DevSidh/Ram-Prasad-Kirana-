import 'product.dart';

class CartItem {
  final Product product;
  final bool isWholesale;
  int quantity;
  int? weightGrams;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isWholesale = false,
    this.weightGrams,
  });

  double get unitPrice =>
      isWholesale ? product.wholesalePrice ?? product.price : product.price;

  double get totalPrice => weightGrams == null
      ? unitPrice * quantity
      : unitPrice * weightGrams! / 1000;

  String get formattedWeight {
    final kilograms = (weightGrams ?? 0) / 1000;
    final value =
        kilograms.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$value kg';
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'product': product.toJson(),
      'quantity': quantity,
      'isWholesale': isWholesale,
      if (weightGrams != null) 'weightGrams': weightGrams,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
      isWholesale: json['isWholesale'] as bool? ?? false,
      weightGrams: (json['weightGrams'] as num?)?.toInt(),
    );
  }
}
