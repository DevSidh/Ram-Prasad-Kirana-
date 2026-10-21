class AdminCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final bool isActive;

  const AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    required this.isActive,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminCoupon {
  final String id;
  final String code;
  final String discountType;
  final double? discountPercent;
  final double? discountAmount;
  final double minOrderAmount;
  final double? maxDiscount;
  final int? usageLimit;
  final int? perUserLimit;
  final int usedCount;
  final bool isActive;
  final DateTime? expiresAt;

  const AdminCoupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountPercent,
    required this.discountAmount,
    required this.minOrderAmount,
    required this.maxDiscount,
    required this.usageLimit,
    required this.perUserLimit,
    required this.usedCount,
    required this.isActive,
    required this.expiresAt,
  });

  factory AdminCoupon.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final discountType = json['discountType'];
    final isActive = json['isActive'];
    if (id is! String ||
        code is! String ||
        (discountType != 'PERCENTAGE' && discountType != 'FIXED') ||
        isActive is! bool) {
      throw const FormatException('The server returned invalid coupon details.');
    }
    final rawExpiry = json['expiresAt'];
    final expiresAt =
        rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    if (rawExpiry != null && expiresAt == null) {
      throw const FormatException('The server returned an invalid coupon expiry.');
    }
    return AdminCoupon(
      id: id,
      code: code,
      discountType: discountType == 'FIXED' ? 'FIXED' : 'PERCENTAGE',
      discountPercent: json['discountPercent'] == null
          ? null
          : _asDouble(json['discountPercent']),
      discountAmount: json['discountAmount'] == null
          ? null
          : _asDouble(json['discountAmount']),
      minOrderAmount: _asDouble(json['minOrderAmount']),
      maxDiscount:
          json['maxDiscount'] == null ? null : _asDouble(json['maxDiscount']),
      usageLimit: json['usageLimit'] == null ? null : _asInt(json['usageLimit']),
      perUserLimit:
          json['perUserLimit'] == null ? null : _asInt(json['perUserLimit']),
      usedCount: _asInt(json['usedCount']),
      isActive: isActive,
      expiresAt: expiresAt,
    );
  }
}

class AdminRestockReceipt {
  final String id;
  final String productName;
  final String productSku;
  final String unitLabel;
  final int quantity;
  final int balanceAfter;
  final String? staffName;
  final String? notes;
  final DateTime createdAt;

  const AdminRestockReceipt({
    required this.id,
    required this.productName,
    required this.productSku,
    required this.unitLabel,
    required this.quantity,
    required this.balanceAfter,
    required this.staffName,
    required this.notes,
    required this.createdAt,
  });

  factory AdminRestockReceipt.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final staff = json['staff'];
    final createdAtValue = json['createdAt'];
    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)
        : null;
    if (json['id'] is! String ||
        product is! Map<String, dynamic> ||
        createdAt == null) {
      throw const FormatException('The server returned invalid restock history.');
    }
    return AdminRestockReceipt(
      id: json['id'] as String,
      productName: product['name']?.toString() ?? '',
      productSku: product['sku']?.toString() ?? '',
      unitLabel: product['unitLabel']?.toString() ?? 'unit',
      quantity: _asInt(json['quantity']),
      balanceAfter: _asInt(json['balanceAfter']),
      staffName:
          staff is Map<String, dynamic> ? staff['name']?.toString() : null,
      notes: json['notes']?.toString(),
      createdAt: createdAt,
    );
  }
}

class AdminProduct {
  final String id;
  final String name;
  final String sku;
  final String slug;
  final String categoryId;
  final String categoryName;
  final String? imageUrl;
  final String? brand;
  final String? description;
  final String? origin;
  final String unitLabel;
  final double price;
  final double? originalPrice;
  final bool isWholesale;
  final double? wholesalePrice;
  final int wholesaleMinimumQuantity;
  final int lowStockThreshold;
  final int stock;
  final bool isActive;
  final bool isFeatured;
  final bool isVendingDrink;
  final bool isBestSeller;

  const AdminProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.slug,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    this.brand,
    this.description,
    this.origin,
    this.unitLabel = '1 pc',
    required this.price,
    this.originalPrice,
    this.isWholesale = false,
    this.wholesalePrice,
    this.wholesaleMinimumQuantity = 1,
    this.lowStockThreshold = 10,
    required this.stock,
    required this.isActive,
    required this.isFeatured,
    this.isVendingDrink = false,
    this.isBestSeller = false,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final inventory = json['inventory'];
    final stockValue = json['stock'] ??
        json['totalStock'] ??
        (inventory is Map<String, dynamic> ? inventory['totalStock'] : null);

    return AdminProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ??
          (category is Map<String, dynamic> ? category['id']?.toString() : null) ??
          '',
      categoryName:
          category is Map<String, dynamic> ? category['name']?.toString() ?? '' : '',
      imageUrl: json['imageUrl']?.toString(),
      brand: json['brand']?.toString(),
      description: json['description']?.toString(),
      origin: json['origin']?.toString(),
      unitLabel: json['unitLabel']?.toString() ??
          json['weight']?.toString() ??
          '1 pc',
      price: _asDouble(json['price']),
      originalPrice: json['originalPrice'] == null
          ? null
          : _asDouble(json['originalPrice']),
      isWholesale: json['isWholesale'] as bool? ?? false,
      wholesalePrice: json['wholesalePrice'] == null
          ? null
          : _asDouble(json['wholesalePrice']),
      wholesaleMinimumQuantity:
          _asInt(json['wholesaleMinimumQuantity'] ?? 1),
      lowStockThreshold: _asInt(json['lowStockThreshold'] ?? 10),
      stock: _asInt(stockValue),
      isActive: json['isActive'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isVendingDrink: json['isVendingDrink'] as bool? ?? false,
      isBestSeller: json['isBestSeller'] as bool? ?? false,
    );
  }

  AdminProduct copyWith({
    String? sku,
    bool? isFeatured,
    bool? isVendingDrink,
    bool? isBestSeller,
    String? imageUrl,
    double? price,
    double? originalPrice,
    bool clearOriginalPrice = false,
  }) {
    return AdminProduct(
      id: id,
      name: name,
      sku: sku ?? this.sku,
      slug: slug,
      categoryId: categoryId,
      categoryName: categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: brand,
      description: description,
      origin: origin,
      unitLabel: unitLabel,
      price: price ?? this.price,
      originalPrice:
          clearOriginalPrice ? null : originalPrice ?? this.originalPrice,
      isWholesale: isWholesale,
      wholesalePrice: wholesalePrice,
      wholesaleMinimumQuantity: wholesaleMinimumQuantity,
      lowStockThreshold: lowStockThreshold,
      stock: stock,
      isActive: isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      isVendingDrink: isVendingDrink ?? this.isVendingDrink,
      isBestSeller: isBestSeller ?? this.isBestSeller,
    );
  }
}

class AdminDashboard {
  final Map<String, dynamic> products;
  final Map<String, dynamic> customers;
  final Map<String, dynamic> orders;
  final Map<String, dynamic> sales;
  final List<Map<String, dynamic>> recentOrders;

  const AdminDashboard({
    required this.products,
    required this.customers,
    required this.orders,
    required this.sales,
    required this.recentOrders,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) {
      final value = json[key];
      return value is Map<String, dynamic> ? value : const {};
    }

    final rawOrders = json['recentOrders'];
    return AdminDashboard(
      products: section('products'),
      customers: section('customers'),
      orders: section('orders'),
      sales: section('sales'),
      recentOrders: rawOrders is List
          ? rawOrders.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}

class AdminDeliveryPerson {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isActive;
  final bool isAvailable;
  final int activeDeliveries;

  const AdminDeliveryPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.isAvailable,
    required this.activeDeliveries,
  });

  factory AdminDeliveryPerson.fromJson(Map<String, dynamic> json) {
    return AdminDeliveryPerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? false,
      activeDeliveries: _asInt(json['activeDeliveries']),
    );
  }
}

class AdminPendingDeliveryCash {
  final String id;
  final String orderNumber;
  final String deliveryPersonName;
  final double cashCollected;
  final String? deliveredAt;

  const AdminPendingDeliveryCash({
    required this.id,
    required this.orderNumber,
    required this.deliveryPersonName,
    required this.cashCollected,
    required this.deliveredAt,
  });

  factory AdminPendingDeliveryCash.fromJson(Map<String, dynamic> json) {
    return AdminPendingDeliveryCash(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      deliveryPersonName: json['deliveryPersonName']?.toString() ?? '',
      cashCollected: _asDouble(json['cashCollected']),
      deliveredAt: json['deliveredAt']?.toString(),
    );
  }
}

class AdminWholesaleItem {
  final String id;
  final String name;
  final String sku;
  final String slug;
  final String categoryId;
  final String categoryName;
  final String? brand;
  final double price;
  final int stock;
  final int minimumQuantity;
  final String? description;
  final String? origin;
  final String? imageUrl;
  final String unitLabel;
  final bool isActive;

  const AdminWholesaleItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.slug,
    required this.categoryId,
    required this.categoryName,
    required this.brand,
    required this.price,
    required this.stock,
    required this.minimumQuantity,
    required this.description,
    required this.origin,
    required this.imageUrl,
    required this.unitLabel,
    required this.isActive,
  });

  factory AdminWholesaleItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return AdminWholesaleItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ??
          (category is Map<String, dynamic>
              ? category['id']?.toString()
              : null) ??
          '',
      categoryName: category is Map<String, dynamic>
          ? category['name']?.toString() ?? ''
          : '',
      brand: json['brand']?.toString(),
      price: _asDouble(json['price']),
      stock: _asInt(json['stock']),
      minimumQuantity: _asInt(json['minimumQuantity'] ?? 1),
      description: json['description']?.toString(),
      origin: json['origin']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      unitLabel: json['unitLabel']?.toString() ?? '1 pc',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminOrder {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String? couponCode;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String shippingAddress;
  final String deliveryInstructions;
  final String? createdAt;
  final List<AdminOrderItem> items;
  final List<Map<String, dynamic>> statusHistory;
  final String? deliveryId;
  final String? deliveryStatus;
  final String? deliveryPersonId;
  final String? deliveryPersonName;
  final List<Map<String, dynamic>> deliveryHistory;
  final DateTime? scheduledDeliveryAt;

  const AdminOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    this.couponCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.shippingAddress,
    required this.deliveryInstructions,
    required this.createdAt,
    required this.items,
    required this.statusHistory,
    this.deliveryId,
    this.deliveryStatus,
    this.deliveryPersonId,
    this.deliveryPersonName,
    this.deliveryHistory = const [],
    this.scheduledDeliveryAt,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final shipping = json['shipping'];
    final items = json['items'];
    final history = json['statusHistory'];
    final delivery = json['delivery'];
    final deliveryPerson = delivery is Map<String, dynamic>
        ? delivery['deliveryPerson']
        : null;
    final deliveryHistory =
        delivery is Map<String, dynamic> ? delivery['statusHistory'] : null;
    final rawScheduledDeliveryAt = json['scheduledDeliveryAt'];
    final scheduledDeliveryAt = rawScheduledDeliveryAt is String
        ? DateTime.tryParse(rawScheduledDeliveryAt)
        : null;
    if (rawScheduledDeliveryAt != null && scheduledDeliveryAt == null) {
      throw const FormatException(
        'The server returned an invalid delivery time.',
      );
    }
    final addressParts = shipping is Map<String, dynamic>
        ? [
            shipping['address'],
            shipping['city'],
            shipping['district'],
            shipping['province'],
            shipping['postalCode'],
          ]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .toList()
        : <String>[];
    return AdminOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PLACED',
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      subtotal: _asDouble(json['subtotal']),
      deliveryFee: _asDouble(json['deliveryFee']),
      discount: _asDouble(json['discount']),
      total: _asDouble(json['total']),
      couponCode: json['couponCode']?.toString(),
      customerName: customer is Map<String, dynamic>
          ? customer['name']?.toString() ?? ''
          : shipping is Map<String, dynamic>
              ? shipping['name']?.toString() ?? ''
              : '',
      customerPhone: customer is Map<String, dynamic>
          ? customer['phone']?.toString() ??
              (shipping is Map<String, dynamic>
                  ? shipping['phone']?.toString() ?? ''
                  : '')
          : shipping is Map<String, dynamic>
              ? shipping['phone']?.toString() ?? ''
              : '',
      customerEmail: customer is Map<String, dynamic>
          ? customer['email']?.toString() ?? ''
          : '',
      shippingAddress: addressParts.join(', '),
      deliveryInstructions: shipping is Map<String, dynamic>
          ? shipping['instructions']?.toString() ?? ''
          : '',
      createdAt: json['createdAt']?.toString(),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(AdminOrderItem.fromJson)
              .toList()
          : const [],
      statusHistory: history is List
          ? history.whereType<Map<String, dynamic>>().toList()
          : const [],
      deliveryId: delivery is Map<String, dynamic>
          ? delivery['id']?.toString()
          : null,
      deliveryStatus: delivery is Map<String, dynamic>
          ? delivery['status']?.toString()
          : null,
      deliveryPersonId: delivery is Map<String, dynamic>
          ? delivery['deliveryPersonId']?.toString()
          : null,
      deliveryPersonName: deliveryPerson is Map<String, dynamic>
          ? deliveryPerson['name']?.toString()
          : null,
      deliveryHistory: deliveryHistory is List
          ? deliveryHistory.whereType<Map<String, dynamic>>().toList()
          : const [],
      scheduledDeliveryAt: scheduledDeliveryAt,
    );
  }
}

class AdminOrderItem {
  final String name;
  final String sku;
  final int quantity;
  final double price;
  final double total;
  final bool isWholesale;

  const AdminOrderItem({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.price,
    required this.total,
    this.isWholesale = false,
  });

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      quantity: _asInt(json['quantity']),
      price: _asDouble(json['price']),
      total: _asDouble(json['total']),
      isWholesale: json['isWholesale'] as bool? ?? false,
    );
  }
}

class AdminCustomer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isActive;
  final String? createdAt;
  final int orderCount;
  final double orderValue;
  final List<Map<String, dynamic>> addresses;
  final List<Map<String, dynamic>> recentOrders;

  const AdminCustomer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.createdAt,
    required this.orderCount,
    required this.orderValue,
    required this.addresses,
    required this.recentOrders,
  });

  factory AdminCustomer.fromJson(Map<String, dynamic> json) {
    final addresses = json['addresses'];
    final recentOrders = json['recentOrders'];
    return AdminCustomer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt']?.toString(),
      orderCount: _asInt(json['orderCount']),
      orderValue: _asDouble(json['orderValue']),
      addresses: addresses is List
          ? addresses.whereType<Map<String, dynamic>>().toList()
          : const [],
      recentOrders: recentOrders is List
          ? recentOrders.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
