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
  final String? productId;
  final String? assignedUserId;
  final String discountType;
  final double? discountPercent;
  final double? discountAmount;
  final double minOrderAmount;
  final double? maxDiscount;
  final int? usageLimit;
  final int? perUserLimit;
  final int usedCount;
  final bool isActive;
  final bool isAnnounced;
  final DateTime? expiresAt;

  const AdminCoupon({
    required this.id,
    required this.code,
    this.productId,
    this.assignedUserId,
    required this.discountType,
    required this.discountPercent,
    required this.discountAmount,
    required this.minOrderAmount,
    required this.maxDiscount,
    required this.usageLimit,
    required this.perUserLimit,
    required this.usedCount,
    required this.isActive,
    this.isAnnounced = false,
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
      throw const FormatException(
          'The server returned invalid coupon details.');
    }
    final rawExpiry = json['expiresAt'];
    final expiresAt = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    if (rawExpiry != null && expiresAt == null) {
      throw const FormatException(
          'The server returned an invalid coupon expiry.');
    }
    return AdminCoupon(
      id: id,
      code: code,
      productId: json['productId']?.toString(),
      assignedUserId: json['assignedUserId']?.toString(),
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
      usageLimit:
          json['usageLimit'] == null ? null : _asInt(json['usageLimit']),
      perUserLimit:
          json['perUserLimit'] == null ? null : _asInt(json['perUserLimit']),
      usedCount: _asInt(json['usedCount']),
      isActive: isActive,
      isAnnounced: json['isAnnounced'] as bool? ?? false,
      expiresAt: expiresAt,
    );
  }
}

class AdminRestockReceipt {
  final String id;
  final String productName;
  final String productSku;
  final String unitLabel;
  final double quantity;
  final double balanceAfter;
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
    final createdAt =
        createdAtValue is String ? DateTime.tryParse(createdAtValue) : null;
    if (json['id'] is! String ||
        product is! Map<String, dynamic> ||
        createdAt == null) {
      throw const FormatException(
          'The server returned invalid restock history.');
    }
    return AdminRestockReceipt(
      id: json['id'] as String,
      productName: product['name']?.toString() ?? '',
      productSku: product['sku']?.toString() ?? '',
      unitLabel: product['unitLabel']?.toString() ?? 'unit',
      quantity: _asDouble(json['quantity']),
      balanceAfter: _asDouble(json['balanceAfter']),
      staffName:
          staff is Map<String, dynamic> ? staff['name']?.toString() : null,
      notes: json['notes']?.toString(),
      createdAt: createdAt,
    );
  }
}

class AdminSupplierPurchaseBillItem {
  const AdminSupplierPurchaseBillItem({
    required this.name,
    required this.sku,
    required this.unitLabel,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final String name;
  final String sku;
  final String unitLabel;
  final double quantity;
  final double unitCost;
  final double lineTotal;

  factory AdminSupplierPurchaseBillItem.fromJson(Map<String, dynamic> json) {
    return AdminSupplierPurchaseBillItem(
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      unitLabel: json['unitLabel']?.toString() ?? 'unit',
      quantity: _asDouble(json['quantity']),
      unitCost: _asDouble(json['unitCost']),
      lineTotal: _asDouble(json['lineTotal']),
    );
  }
}

class AdminSupplierPurchaseBill {
  const AdminSupplierPurchaseBill({
    required this.id,
    required this.supplierName,
    required this.supplierPhone,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.deliveryPerson,
    required this.notes,
    required this.totalCost,
    required this.status,
    required this.createdAt,
    required this.hasPhoto,
    required this.items,
  });

  final String id;
  final String supplierName;
  final String? supplierPhone;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? deliveryPerson;
  final String? notes;
  final double totalCost;
  final String status;
  final DateTime createdAt;
  final bool hasPhoto;
  final List<AdminSupplierPurchaseBillItem> items;

  factory AdminSupplierPurchaseBill.fromJson(Map<String, dynamic> json) {
    final invoiceDate = DateTime.tryParse(json['invoiceDate'] as String? ?? '');
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final rawItems = json['items'];
    if (json['id'] is! String ||
        json['supplierName'] is! String ||
        json['invoiceNumber'] is! String ||
        invoiceDate == null ||
        createdAt == null ||
        rawItems is! List ||
        rawItems.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException(
        'The server returned invalid supplier purchase bill details.',
      );
    }
    return AdminSupplierPurchaseBill(
      id: json['id'] as String,
      supplierName: json['supplierName'] as String,
      supplierPhone: json['supplierPhone'] as String?,
      invoiceNumber: json['invoiceNumber'] as String,
      invoiceDate: invoiceDate,
      deliveryPerson: json['deliveryPerson'] as String?,
      notes: json['notes'] as String?,
      totalCost: _asDouble(json['totalCost']),
      status: json['status'] as String? ?? 'RECEIVED',
      createdAt: createdAt,
      hasPhoto: json['hasPhoto'] == true,
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(AdminSupplierPurchaseBillItem.fromJson)
          .toList(growable: false),
    );
  }
}

class AdminSupplierPurchaseBillPage {
  const AdminSupplierPurchaseBillPage({
    required this.bills,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AdminSupplierPurchaseBill> bills;
  final int page;
  final int pageSize;
  final int total;

  factory AdminSupplierPurchaseBillPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
    required int pageSize,
  }) {
    final rawBills = json['bills'];
    final rawPagination = json['pagination'];
    if (rawBills is! List || rawPagination is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned invalid supplier bill history.',
      );
    }
    return AdminSupplierPurchaseBillPage(
      bills: rawBills
          .whereType<Map<String, dynamic>>()
          .map(AdminSupplierPurchaseBill.fromJson)
          .toList(growable: false),
      page: _asInt(rawPagination['page'], fallback: page),
      pageSize: _asInt(rawPagination['pageSize'], fallback: pageSize),
      total: _asInt(rawPagination['total']),
    );
  }
}

class AdminInventoryBatch {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String? barcode;
  final String? imageUrl;
  final String categoryName;
  final String unitLabel;
  final String? lotNumber;
  final DateTime? manufacturedAt;
  final DateTime? expiresAt;
  final double receivedQuantity;
  final double remainingQuantity;
  final int? daysRemaining;
  final String expiryStatus;
  final bool datesVerified;

  const AdminInventoryBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.barcode,
    required this.imageUrl,
    required this.categoryName,
    required this.unitLabel,
    required this.lotNumber,
    required this.manufacturedAt,
    required this.expiresAt,
    required this.receivedQuantity,
    required this.remainingQuantity,
    required this.daysRemaining,
    required this.expiryStatus,
    required this.datesVerified,
  });

  factory AdminInventoryBatch.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return AdminInventoryBatch(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      categoryName: json['categoryName']?.toString() ?? '',
      unitLabel: json['unitLabel']?.toString() ?? '',
      lotNumber: json['lotNumber']?.toString(),
      manufacturedAt: parseDate(json['manufacturedAt']),
      expiresAt: parseDate(json['expiresAt']),
      receivedQuantity: _asDouble(json['receivedQuantity']),
      remainingQuantity: _asDouble(json['remainingQuantity']),
      daysRemaining: json['daysRemaining'] is num
          ? (json['daysRemaining'] as num).toInt()
          : null,
      expiryStatus: json['expiryStatus']?.toString() ?? 'dates_unverified',
      datesVerified: json['datesVerified'] as bool? ?? false,
    );
  }
}

class AdminInventoryExpiryPage {
  final List<AdminInventoryBatch> batches;
  final int warningDays;
  final int expiringSoonBatches;
  final int expiringSoonProducts;
  final int expiredBatches;
  final int expiredProducts;
  final int expiringTodayBatches;
  final int expiringTodayProducts;
  final int page;
  final int pageSize;
  final int total;

  const AdminInventoryExpiryPage({
    required this.batches,
    required this.warningDays,
    required this.expiringSoonBatches,
    required this.expiringSoonProducts,
    required this.expiredBatches,
    required this.expiredProducts,
    required this.expiringTodayBatches,
    required this.expiringTodayProducts,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AdminInventoryExpiryPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final pagination = json['pagination'];
    final rawBatches = json['batches'];
    if (summary is! Map<String, dynamic> ||
        pagination is! Map<String, dynamic> ||
        rawBatches is! List ||
        rawBatches.any((batch) => batch is! Map<String, dynamic>)) {
      throw const FormatException('The server returned invalid expiry data.');
    }
    return AdminInventoryExpiryPage(
      batches: rawBatches
          .cast<Map<String, dynamic>>()
          .map(AdminInventoryBatch.fromJson)
          .toList(growable: false),
      warningDays: _asInt(summary['warningDays']),
      expiringSoonBatches: _asInt(summary['expiringSoonBatches']),
      expiringSoonProducts: _asInt(summary['expiringSoonProducts']),
      expiredBatches: _asInt(summary['expiredBatches']),
      expiredProducts: _asInt(summary['expiredProducts']),
      expiringTodayBatches: _asInt(summary['expiringTodayBatches']),
      expiringTodayProducts: _asInt(summary['expiringTodayProducts']),
      page: _asInt(pagination['page'], fallback: 1),
      pageSize: _asInt(pagination['pageSize'], fallback: 25),
      total: _asInt(pagination['total']),
    );
  }
}

class AdminProduct {
  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final String slug;
  final String categoryId;
  final String categoryName;
  final String? imageUrl;
  final List<String> imageUrls;
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
  final double? weightStockKg;
  final bool isActive;
  final bool isFeatured;
  final bool isVendingDrink;
  final String? vendingSection;
  final bool isBestSeller;

  double get availableStock => weightStockKg ?? stock.toDouble();
  String get availableStockLabel => weightStockKg == null
      ? stock.toString()
      : weightStockKg!.toStringAsFixed(3).replaceFirst(
            RegExp(r'\.?0+$'),
            '',
          );

  const AdminProduct({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.slug,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    this.imageUrls = const [],
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
    this.weightStockKg,
    required this.isActive,
    required this.isFeatured,
    this.isVendingDrink = false,
    this.vendingSection,
    this.isBestSeller = false,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final inventory = json['inventory'];
    final rawImageUrls = json['imageUrls'];
    final stockValue = json['stock'] ??
        json['totalStock'] ??
        (inventory is Map<String, dynamic> ? inventory['totalStock'] : null);

    return AdminProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      slug: json['slug']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ??
          (category is Map<String, dynamic>
              ? category['id']?.toString()
              : null) ??
          '',
      categoryName: category is Map<String, dynamic>
          ? category['name']?.toString() ?? ''
          : '',
      imageUrl: json['imageUrl']?.toString(),
      imageUrls: rawImageUrls is List
          ? rawImageUrls.whereType<String>().toList(growable: false)
          : const [],
      brand: json['brand']?.toString(),
      description: json['description']?.toString(),
      origin: json['origin']?.toString(),
      unitLabel:
          json['unitLabel']?.toString() ?? json['weight']?.toString() ?? '1 pc',
      price: _asDouble(json['price']),
      originalPrice: json['originalPrice'] == null
          ? null
          : _asDouble(json['originalPrice']),
      isWholesale: json['isWholesale'] as bool? ?? false,
      wholesalePrice: json['wholesalePrice'] == null
          ? null
          : _asDouble(json['wholesalePrice']),
      wholesaleMinimumQuantity: _asInt(json['wholesaleMinimumQuantity'] ?? 1),
      lowStockThreshold: _asInt(json['lowStockThreshold'] ?? 10),
      stock: _asInt(stockValue),
      weightStockKg: json['weightStockKg'] == null
          ? null
          : _asDouble(json['weightStockKg']),
      isActive: json['isActive'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isVendingDrink: json['isVendingDrink'] as bool? ?? false,
      vendingSection: json['vendingSection'] as String?,
      isBestSeller: json['isBestSeller'] as bool? ?? false,
    );
  }

  AdminProduct copyWith({
    String? sku,
    bool? isFeatured,
    bool? isVendingDrink,
    String? vendingSection,
    bool? isBestSeller,
    String? imageUrl,
    List<String>? imageUrls,
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
      imageUrls: imageUrls ?? this.imageUrls,
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
      weightStockKg: weightStockKg,
      isActive: isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      isVendingDrink: isVendingDrink ?? this.isVendingDrink,
      vendingSection: vendingSection ?? this.vendingSection,
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
    final deliveryPerson =
        delivery is Map<String, dynamic> ? delivery['deliveryPerson'] : null;
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
          ].whereType<String>().where((part) => part.trim().isNotEmpty).toList()
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
      deliveryId:
          delivery is Map<String, dynamic> ? delivery['id']?.toString() : null,
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
  final String profileId;
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
    required this.profileId,
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
      profileId: json['profileId']?.toString() ?? '',
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

class AdminCustomerRemovalRecord {
  final String profileId;
  final DateTime removedAt;
  final String removedByName;
  final String removedByProfileId;

  const AdminCustomerRemovalRecord({
    required this.profileId,
    required this.removedAt,
    required this.removedByName,
    required this.removedByProfileId,
  });

  factory AdminCustomerRemovalRecord.fromJson(Map<String, dynamic> json) {
    final removedAt = DateTime.tryParse(json['removedAt']?.toString() ?? '');
    if (json['profileId'] is! String ||
        removedAt == null ||
        json['removedByName'] is! String ||
        json['removedByProfileId'] is! String) {
      throw const FormatException(
        'The server returned invalid customer removal history.',
      );
    }
    return AdminCustomerRemovalRecord(
      profileId: json['profileId'] as String,
      removedAt: removedAt,
      removedByName: json['removedByName'] as String,
      removedByProfileId: json['removedByProfileId'] as String,
    );
  }
}

class AdminStreakReward {
  final int day;
  final String title;
  final String description;
  final String? couponId;
  final String? couponCode;

  const AdminStreakReward({
    required this.day,
    required this.title,
    required this.description,
    this.couponId,
    this.couponCode,
  });

  factory AdminStreakReward.fromJson(Map<String, dynamic> json) {
    if (json['day'] is! int ||
        json['title'] is! String ||
        json['description'] is! String ||
        (json['couponId'] != null && json['couponId'] is! String) ||
        (json['couponCode'] != null && json['couponCode'] is! String)) {
      throw const FormatException(
          'The server returned an invalid streak reward.');
    }
    return AdminStreakReward(
      day: json['day'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      couponId: json['couponId'] as String?,
      couponCode: json['couponCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        if (couponId != null) 'couponId': couponId,
      };
}

class AdminStreakClaim {
  final int day;
  final String title;
  final String description;
  final String customerName;
  final String profileId;
  final String claimedAt;

  const AdminStreakClaim({
    required this.day,
    required this.title,
    required this.description,
    required this.customerName,
    required this.profileId,
    required this.claimedAt,
  });

  factory AdminStreakClaim.fromJson(Map<String, dynamic> json) {
    if (json['day'] is! int ||
        json['title'] is! String ||
        json['description'] is! String ||
        json['customerName'] is! String ||
        json['profileId'] is! String ||
        json['claimedAt'] is! String) {
      throw const FormatException(
          'The server returned an invalid streak claim.');
    }
    return AdminStreakClaim(
      day: json['day'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      customerName: json['customerName'] as String,
      profileId: json['profileId'] as String,
      claimedAt: json['claimedAt'] as String,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
