import 'cart_item.dart';
import 'address.dart';

class Order {
  final String id;
  final String orderNumber;
  final List<CartItem> items;
  final Address address;
  final String status; // PLACED, CONFIRMED, PREPARING, PACKED, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
  final String paymentMethod; // COD, ESEWA, KHALTI, CARD
  final String paymentStatus; // PENDING, COMPLETED, FAILED
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double tip;
  final double total;
  final String createdAt;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;

  Order({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.address,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.tip = 0.0,
    required this.total,
    required this.createdAt,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItem.fromJson(e))
              .toList() ??
          [],
      address: Address.fromJson(json['address'] ?? {}),
      status: json['status'] ?? 'PLACED',
      paymentMethod: json['paymentMethod'] ?? 'COD',
      paymentStatus: json['paymentStatus'] ?? 'PENDING',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      deliveryPersonName: json['deliveryPersonName'],
      deliveryPersonPhone: json['deliveryPersonPhone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'address': address.toJson(),
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      'tip': tip,
      'total': total,
      'createdAt': createdAt,
      'deliveryPersonName': deliveryPersonName,
      'deliveryPersonPhone': deliveryPersonPhone,
    };
  }
}
