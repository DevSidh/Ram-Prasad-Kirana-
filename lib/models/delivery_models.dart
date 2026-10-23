class DeliveryProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isAvailable;

  const DeliveryProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isAvailable,
  });

  factory DeliveryProfile.fromJson(Map<String, dynamic> json) {
    return DeliveryProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
    );
  }
}

class DeliveryOrder {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double total;
  final double cashDue;
  final String customerName;
  final String customerPhone;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? customerLatitude;
  final double? customerLongitude;
  final DateTime? customerLocationUpdatedAt;
  final String instructions;
  final String? createdAt;
  final List<DeliveryOrderItem> items;

  const DeliveryOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.cashDue,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.customerLatitude,
    this.customerLongitude,
    this.customerLocationUpdatedAt,
    required this.instructions,
    required this.createdAt,
    required this.items,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PROCESSING',
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      total: _number(json['total']),
      cashDue: _number(json['cashDue']),
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: json['latitude'] == null ? null : _number(json['latitude']),
      longitude: json['longitude'] == null ? null : _number(json['longitude']),
      customerLatitude: json['customerLatitude'] == null
          ? null
          : _number(json['customerLatitude']),
      customerLongitude: json['customerLongitude'] == null
          ? null
          : _number(json['customerLongitude']),
      customerLocationUpdatedAt: json['customerLocationUpdatedAt'] is String
          ? DateTime.tryParse(json['customerLocationUpdatedAt'] as String)
          : null,
      instructions: json['instructions']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(DeliveryOrderItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class DeliveryOrderItem {
  final String name;
  final int quantity;
  final int? weightGrams;

  const DeliveryOrderItem({
    required this.name,
    required this.quantity,
    this.weightGrams,
  });

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      name: json['name']?.toString() ?? '',
      quantity: _integer(json['quantity']),
      weightGrams:
          json['weightGrams'] == null ? null : _integer(json['weightGrams']),
    );
  }
}

class DeliveryAssignment {
  final String id;
  final String status;
  final String? assignedAt;
  final String? pickedUpAt;
  final String? deliveredAt;
  final double cashCollected;
  final double cashHandedOver;
  final String? cashHandedOverAt;
  final DeliveryOrder order;

  const DeliveryAssignment({
    required this.id,
    required this.status,
    required this.assignedAt,
    required this.pickedUpAt,
    required this.deliveredAt,
    required this.cashCollected,
    required this.cashHandedOver,
    required this.cashHandedOverAt,
    required this.order,
  });

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    if (order is! Map<String, dynamic>) {
      throw const FormatException('Delivery assignment has no order details.');
    }
    return DeliveryAssignment(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ASSIGNED',
      assignedAt: json['assignedAt']?.toString(),
      pickedUpAt: json['pickedUpAt']?.toString(),
      deliveredAt: json['deliveredAt']?.toString(),
      cashCollected: _number(json['cashCollected']),
      cashHandedOver: _number(json['cashHandedOver']),
      cashHandedOverAt: json['cashHandedOverAt']?.toString(),
      order: DeliveryOrder.fromJson(order),
    );
  }
}

class DeliverySummary {
  final int assigned;
  final int inProgress;
  final int deliveredToday;
  final double cashCollectedToday;
  final double cashToHandOver;

  const DeliverySummary({
    required this.assigned,
    required this.inProgress,
    required this.deliveredToday,
    required this.cashCollectedToday,
    required this.cashToHandOver,
  });

  factory DeliverySummary.fromJson(Map<String, dynamic>? json) {
    return DeliverySummary(
      assigned: _integer(json?['assigned']),
      inProgress: _integer(json?['inProgress']),
      deliveredToday: _integer(json?['deliveredToday']),
      cashCollectedToday: _number(json?['cashCollectedToday']),
      cashToHandOver: _number(json?['cashToHandOver']),
    );
  }
}

class DeliveryAssignmentPage {
  final List<DeliveryAssignment> assignments;
  final DeliverySummary summary;

  const DeliveryAssignmentPage({
    required this.assignments,
    required this.summary,
  });

  factory DeliveryAssignmentPage.fromJson(Map<String, dynamic> json) {
    final assignments = json['assignments'];
    if (assignments is! List) {
      throw const FormatException(
          'The server returned an invalid delivery list.');
    }
    final summary = json['summary'];
    return DeliveryAssignmentPage(
      assignments: assignments
          .whereType<Map<String, dynamic>>()
          .map(DeliveryAssignment.fromJson)
          .toList(),
      summary: DeliverySummary.fromJson(
        summary is Map<String, dynamic> ? summary : null,
      ),
    );
  }
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
