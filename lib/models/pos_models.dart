double _posDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int _posInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.price,
    required this.unitLabel,
    required this.available,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final double price;
  final String unitLabel;
  final int available;
  final String? imageUrl;

  factory PosProduct.fromJson(Map<String, dynamic> json) => PosProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String,
        barcode: json['barcode'] as String?,
        price: _posDouble(json['price']),
        unitLabel: json['unitLabel'] as String? ?? 'unit',
        available: _posInt(json['available']),
        imageUrl: json['imageUrl'] as String?,
      );
}

class BillingStaffAccount {
  const BillingStaffAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.emailVerified,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final bool emailVerified;

  factory BillingStaffAccount.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['name'] is! String ||
        json['email'] is! String ||
        json['role'] is! String ||
        json['isActive'] is! bool ||
        json['emailVerified'] is! bool) {
      throw const FormatException(
        'The server returned an invalid billing staff account.',
      );
    }
    return BillingStaffAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['isActive'] as bool,
      emailVerified: json['emailVerified'] as bool,
    );
  }
}

class PosSaleItem {
  const PosSaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.weightGrams,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String id;
  final String? productId;
  final String productName;
  final String sku;
  final int quantity;
  final int? weightGrams;
  final double unitPrice;
  final double lineTotal;

  factory PosSaleItem.fromJson(Map<String, dynamic> json) => PosSaleItem(
        id: json['id'] as String? ?? '',
        productId: json['productId'] as String?,
        productName: json['productName'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        quantity: _posInt(json['quantity']),
        weightGrams:
            json['weightGrams'] == null ? null : _posInt(json['weightGrams']),
        unitPrice: _posDouble(json['unitPrice']),
        lineTotal: _posDouble(json['lineTotal']),
      );
}

class PosPaymentCollection {
  const PosPaymentCollection({
    required this.id,
    required this.amount,
    required this.method,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final double amount;
  final String method;
  final String? note;
  final DateTime createdAt;

  factory PosPaymentCollection.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (json['id'] is! String || createdAt == null) {
      throw const FormatException(
        'The server returned an invalid payment collection.',
      );
    }
    return PosPaymentCollection(
      id: json['id'] as String,
      amount: _posDouble(json['amount']),
      method: json['method'] as String? ?? 'CASH',
      note: json['note'] as String?,
      createdAt: createdAt,
    );
  }
}

class PosSale {
  const PosSale({
    required this.id,
    required this.receiptNumber,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.refundedAmount,
    required this.createdAt,
    required this.items,
    this.paidAmount,
    this.outstandingAmount,
    this.paymentCollections = const [],
  });

  final String id;
  final String receiptNumber;
  final String? customerName;
  final String? customerPhone;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double discount;
  final double total;
  final double refundedAmount;
  final DateTime createdAt;
  final List<PosSaleItem> items;
  final double? paidAmount;
  final double? outstandingAmount;
  final List<PosPaymentCollection> paymentCollections;

  factory PosSale.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (json['id'] is! String ||
        json['receiptNumber'] is! String ||
        createdAt == null ||
        json['items'] is! List) {
      throw const FormatException('The server returned an invalid POS bill.');
    }
    return PosSale(
      id: json['id'] as String,
      receiptNumber: json['receiptNumber'] as String,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      status: json['status'] as String? ?? 'COMPLETED',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      paymentStatus: json['paymentStatus'] as String? ?? 'COMPLETED',
      subtotal: _posDouble(json['subtotal']),
      discount: _posDouble(json['discount']),
      total: _posDouble(json['total']),
      refundedAmount: _posDouble(json['refundedAmount']),
      createdAt: createdAt,
      paidAmount:
          json['paidAmount'] == null ? null : _posDouble(json['paidAmount']),
      outstandingAmount: json['outstandingAmount'] == null
          ? null
          : _posDouble(json['outstandingAmount']),
      paymentCollections: (json['paymentCollections'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(PosPaymentCollection.fromJson)
              .toList(growable: false) ??
          const [],
      items: (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(PosSaleItem.fromJson)
          .toList(growable: false),
    );
  }
}

class PosSalesPage {
  const PosSalesPage({
    required this.sales,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<PosSale> sales;
  final int page;
  final int pageSize;
  final int total;

  int get pageCount => total == 0 ? 0 : (total / pageSize).ceil();

  factory PosSalesPage.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales'];
    final pagination = json['pagination'];
    if (rawSales is! List || pagination is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned invalid bill history.',
      );
    }
    final page = _posInt(pagination['page']);
    final pageSize = _posInt(pagination['pageSize']);
    final total = _posInt(pagination['total']);
    if (page < 1 || pageSize < 1 || total < 0) {
      throw const FormatException(
        'The server returned invalid bill-history pagination.',
      );
    }
    return PosSalesPage(
      sales: rawSales
          .whereType<Map<String, dynamic>>()
          .map(PosSale.fromJson)
          .toList(growable: false),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }
}

class PosHeldSale {
  const PosHeldSale({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String? customerName;
  final String? customerPhone;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;

  factory PosHeldSale.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final rawItems = json['items'];
    if (json['id'] is! String || createdAt == null || rawItems is! List) {
      throw const FormatException('The server returned an invalid held bill.');
    }
    return PosHeldSale(
      id: json['id'] as String,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      items: rawItems.whereType<Map<String, dynamic>>().toList(growable: false),
      createdAt: createdAt,
    );
  }
}

class PosRefund {
  const PosRefund({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    required this.reason,
    required this.status,
    required this.restockStock,
    required this.requestedBy,
    required this.requestedAt,
  });

  final String id;
  final String receiptNumber;
  final double amount;
  final String reason;
  final String status;
  final bool restockStock;
  final String requestedBy;
  final DateTime requestedAt;

  factory PosRefund.fromJson(Map<String, dynamic> json) {
    final requestedAt = DateTime.tryParse(json['requestedAt'] as String? ?? '');
    if (json['id'] is! String || requestedAt == null) {
      throw const FormatException(
          'The server returned an invalid refund request.');
    }
    return PosRefund(
      id: json['id'] as String,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      amount: _posDouble(json['amount']),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'REQUESTED',
      restockStock: json['restockStock'] as bool? ?? false,
      requestedBy: json['requestedBy'] as String? ?? '',
      requestedAt: requestedAt,
    );
  }
}

class PosExchange {
  const PosExchange({
    required this.id,
    required this.receiptNumber,
    required this.returnedCredit,
    required this.replacementTotal,
    required this.difference,
    required this.paymentMethod,
    required this.status,
    required this.restockReturnedItems,
    required this.requestedAt,
    required this.items,
  });

  final String id;
  final String receiptNumber;
  final double returnedCredit;
  final double replacementTotal;
  final double difference;
  final String? paymentMethod;
  final String status;
  final bool restockReturnedItems;
  final DateTime requestedAt;
  final List<PosExchangeItem> items;

  factory PosExchange.fromJson(Map<String, dynamic> json) {
    final requestedAt = DateTime.tryParse(json['requestedAt'] as String? ?? '');
    if (json['id'] is! String ||
        requestedAt == null ||
        json['items'] is! List) {
      throw const FormatException(
        'The server returned an invalid exchange record.',
      );
    }
    return PosExchange(
      id: json['id'] as String,
      receiptNumber: json['receiptNumber'] as String? ?? '',
      returnedCredit: _posDouble(json['returnedCredit']),
      replacementTotal: _posDouble(json['replacementTotal']),
      difference: _posDouble(json['difference']),
      paymentMethod: json['paymentMethod'] as String?,
      status: json['status'] as String? ?? 'COMPLETED',
      restockReturnedItems: json['restockReturnedItems'] as bool? ?? true,
      requestedAt: requestedAt,
      items: (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(PosExchangeItem.fromJson)
          .toList(growable: false),
    );
  }
}

class PosExchangeItem {
  const PosExchangeItem({
    required this.type,
    required this.productName,
    required this.quantity,
    required this.weightGrams,
    required this.lineTotal,
  });

  final String type;
  final String productName;
  final int quantity;
  final int? weightGrams;
  final double lineTotal;

  factory PosExchangeItem.fromJson(Map<String, dynamic> json) =>
      PosExchangeItem(
        type: json['type'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        quantity: _posInt(json['quantity']),
        weightGrams:
            json['weightGrams'] == null ? null : _posInt(json['weightGrams']),
        lineTotal: _posDouble(json['lineTotal']),
      );
}

class PosOverview {
  const PosOverview({
    required this.day,
    required this.cashierName,
    required this.shiftId,
    required this.openingCash,
    required this.expectedClosingCash,
    required this.openedAt,
    required this.totalSales,
    required this.completedBills,
    required this.averageBillValue,
    required this.cashSales,
    required this.digitalSales,
    required this.pendingSales,
    required this.refunds,
    required this.cancelledBills,
    required this.openRefundRequests,
    required this.topProducts,
    required this.lowStock,
  });

  final String day;
  final String? cashierName;
  final String? shiftId;
  final double openingCash;
  final double? expectedClosingCash;
  final DateTime? openedAt;
  final double totalSales;
  final int completedBills;
  final double averageBillValue;
  final double cashSales;
  final double digitalSales;
  final double pendingSales;
  final double refunds;
  final int cancelledBills;
  final int openRefundRequests;
  final List<({String name, int sold})> topProducts;
  final List<({String name, int available, String unitLabel})> lowStock;

  factory PosOverview.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'];
    final shift = json['currentShift'];
    if (metrics is! Map<String, dynamic>) {
      throw const FormatException(
          'The server returned invalid billing metrics.');
    }
    final cashier = json['cashier'];
    final openedAt = shift is Map<String, dynamic>
        ? DateTime.tryParse(shift['openedAt'] as String? ?? '')
        : null;
    return PosOverview(
      day: json['day'] as String? ?? '',
      cashierName:
          cashier is Map<String, dynamic> ? cashier['name'] as String? : null,
      shiftId: shift is Map<String, dynamic> ? shift['id'] as String? : null,
      openingCash:
          shift is Map<String, dynamic> ? _posDouble(shift['openingCash']) : 0,
      expectedClosingCash:
          shift is Map<String, dynamic> && shift['expectedClosingCash'] is num
              ? _posDouble(shift['expectedClosingCash'])
              : null,
      openedAt: openedAt,
      totalSales: _posDouble(metrics['totalSales']),
      completedBills: _posInt(metrics['completedBills']),
      averageBillValue: _posDouble(metrics['averageBillValue']),
      cashSales: _posDouble(metrics['cashSales']),
      digitalSales: _posDouble(metrics['digitalSales']),
      pendingSales: _posDouble(metrics['pendingSales']),
      refunds: _posDouble(metrics['refunds']),
      cancelledBills: _posInt(metrics['cancelledBills']),
      openRefundRequests: _posInt(metrics['openRefundRequests']),
      topProducts: (json['topProducts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => (
                name: item['name'] as String? ?? '',
                sold: _posInt(item['sold']),
              ))
          .toList(growable: false),
      lowStock: (json['lowStock'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => (
                name: item['name'] as String? ?? '',
                available: _posInt(item['available']),
                unitLabel: item['unitLabel'] as String? ?? 'unit',
              ))
          .toList(growable: false),
    );
  }
}
