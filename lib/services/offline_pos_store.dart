import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pos_models.dart';

/// Persistent local POS catalog used by the Windows billing screen when the
/// server cannot be reached. The server remains the source of truth online.
class OfflinePosStore {
  const OfflinePosStore();

  Future<File> _catalogFile() async {
    final directory = await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/catalog.json');
  }

  Future<File> _pendingProductsFile() async {
    final directory = await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/pending_products.json');
  }

  Future<File> _categoriesFile() async {
    final directory = await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/categories.json');
  }

  Future<File> _dashboardFile() async {
    final directory = await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/dashboard.json');
  }

  Future<void> saveDashboardSnapshot(Map<String, dynamic> snapshot) async {
    if (kIsWeb) return;
    final file = await _dashboardFile();
    await file.writeAsString(jsonEncode(snapshot), flush: true);
  }

  Future<Map<String, dynamic>?> readDashboardSnapshot() async {
    if (kIsWeb) return null;
    try {
      final file = await _dashboardFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<double> readOfflineSalesTotal() async {
    if (kIsWeb) return 0;
    final directory = Directory('C:/Ramprasad store/bills');
    if (!await directory.exists()) return 0;
    var total = 0.0;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is Map<String, dynamic>) {
            final amount = decoded['total'];
            total += amount is num
                ? amount.toDouble()
                : double.tryParse(amount?.toString() ?? '') ?? 0;
          }
        } catch (_) {
          // Skip malformed local bill files while retaining valid totals.
        }
      }
    } catch (_) {
      return total;
    }
    return total;
  }

  /// Loads computer-only bills from the Windows billing folder so they can
  /// appear in the admin invoice history without being uploaded to the server.
  Future<List<PosSale>> readOfflineSales() async {
    if (kIsWeb || !Platform.isWindows) return const [];
    final directory = Directory('C:/Ramprasad store/bills');
    if (!await directory.exists()) return const [];
    final sales = <PosSale>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map<String, dynamic>) continue;
          final invoiceNumber = decoded['invoiceNumber']?.toString().trim();
          final createdAt = DateTime.tryParse(
            decoded['date']?.toString() ??
                decoded['createdAt']?.toString() ??
                '',
          );
          final rawItems = decoded['items'];
          if (invoiceNumber == null ||
              invoiceNumber.isEmpty ||
              createdAt == null ||
              rawItems is! List) {
            continue;
          }
          final items = rawItems.whereType<Map<String, dynamic>>().map((item) {
            final quantityValue = item['quantity'];
            final weightValue = item['weightGrams'];
            return PosSaleItem(
              id: item['id']?.toString() ??
                  '$invoiceNumber-${item['productId'] ?? item['sku'] ?? ''}',
              productId: item['productId']?.toString(),
              productName: item['name']?.toString() ??
                  item['productName']?.toString() ??
                  '',
              sku: item['sku']?.toString() ?? '',
              quantity: quantityValue is num
                  ? quantityValue.toInt()
                  : int.tryParse('$quantityValue') ?? 0,
              weightGrams: weightValue == null
                  ? null
                  : weightValue is num
                      ? weightValue.toInt()
                      : int.tryParse('$weightValue'),
              unitPrice: _offlineNumber(item['unitPrice']),
              lineTotal: _offlineNumber(item['amount'] ?? item['lineTotal']),
            );
          }).toList(growable: false);
          final total = _offlineNumber(decoded['total']);
          final paidAmount = _offlineNumber(decoded['paidAmount']);
          sales.add(PosSale(
            id: 'local-$invoiceNumber',
            receiptNumber: invoiceNumber,
            invoiceNumber: invoiceNumber,
            customerName: decoded['customerName']?.toString(),
            customerPhone: decoded['customerPhone']?.toString(),
            status: decoded['status']?.toString() ?? 'COMPLETED',
            paymentMethod: decoded['paymentMethod']?.toString() ?? 'CASH',
            paymentStatus: decoded['paymentStatus']?.toString() ?? 'COMPLETED',
            subtotal: _offlineNumber(decoded['subtotal']),
            discount: _offlineNumber(decoded['discount']),
            vatRate: _offlineNumber(decoded['vatRate']),
            vatAmount: _offlineNumber(decoded['vatAmount']),
            total: total,
            refundedAmount: _offlineNumber(decoded['refundedAmount']),
            createdAt: createdAt,
            items: items,
            paidAmount: paidAmount,
            outstandingAmount: _offlineNumber(decoded['outstandingAmount']),
            paymentCollections: (decoded['paymentCollections'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((payment) => PosPaymentCollection.fromJson(payment))
                .toList(growable: false),
            localPath: entity.path,
          ));
        } catch (_) {
          // An invalid file should not hide other valid local invoices.
        }
      }
    } catch (_) {
      return sales;
    }
    sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sales;
  }

  static double _offlineNumber(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    if (kIsWeb) return;
    final file = await _categoriesFile();
    await file.writeAsString(jsonEncode(categories), flush: true);
  }

  Future<List<Map<String, dynamic>>> readCategories() async {
    if (kIsWeb) return const [];
    try {
      final file = await _categoriesFile();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PosProduct>> readCatalog() async {
    if (kIsWeb) return const [];
    try {
      final file = await _catalogFile();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['products'] is! List) {
        return const [];
      }
      return (decoded['products'] as List)
          .whereType<Map<String, dynamic>>()
          .map(PosProduct.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCatalog(List<PosProduct> products) async {
    if (kIsWeb) return;
    final pending = await readPendingProducts();
    final combined = <String, PosProduct>{
      for (final product in products) product.id: product,
      for (final entry in pending)
        if (entry['posProduct'] is Map<String, dynamic>)
          (entry['posProduct'] as Map<String, dynamic>)['id'] as String:
              PosProduct.fromJson(entry['posProduct'] as Map<String, dynamic>),
    };
    final file = await _catalogFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'products': combined.values.map(_toJson).toList(growable: false),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  /// Adds partial catalog results without deleting products cached earlier.
  /// Use this for paginated admin screens and server-side search results.
  Future<void> mergeCatalog(List<PosProduct> products) async {
    if (kIsWeb || products.isEmpty) return;
    final merged = <String, PosProduct>{
      for (final product in await readCatalog()) product.id: product,
      for (final product in products) product.id: product,
    };
    await saveCatalog(merged.values.toList(growable: false));
  }

  Future<List<Map<String, dynamic>>> readPendingProducts() async {
    if (kIsWeb) return const [];
    try {
      final file = await _pendingProductsFile();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingProducts(List<Map<String, dynamic>> entries) async {
    if (kIsWeb) return;
    final file = await _pendingProductsFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(entries), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> queueProduct(Map<String, dynamic> fields, double stock) async {
    await _queueCatalogRecord(fields, stock, kind: 'product');
  }

  Future<void> queueWholesaleItem(Map<String, dynamic> fields) async {
    await _queueCatalogRecord(
      fields,
      (fields['stock'] as num?)?.toDouble() ?? 0,
      kind: 'wholesale',
    );
  }

  Future<void> _queueCatalogRecord(
    Map<String, dynamic> fields,
    double stock, {
    required String kind,
  }) async {
    final entries = (await readPendingProducts()).toList();
    final sku = fields['sku']?.toString().trim().toLowerCase() ?? '';
    final barcode = fields['barcode']?.toString().trim().toLowerCase() ?? '';
    final duplicate = entries.any((entry) {
      if ((entry['kind'] ?? 'product') != kind) return false;
      final pendingFields = entry['fields'];
      if (pendingFields is! Map<String, dynamic>) return false;
      final pendingSku = pendingFields['sku']?.toString().trim().toLowerCase();
      final pendingBarcode =
          pendingFields['barcode']?.toString().trim().toLowerCase();
      return (sku.isNotEmpty && pendingSku == sku) ||
          (barcode.isNotEmpty && pendingBarcode == barcode);
    });
    if (duplicate) {
      throw const FormatException(
        'A product with this barcode or SKU is already waiting to sync.',
      );
    }
    final id = '${kind == 'wholesale' ? 'wholesale' : 'offline'}-'
        '${DateTime.now().microsecondsSinceEpoch}';
    final localProduct = PosProduct(
      id: id,
      name: fields['name']?.toString() ?? 'Offline product',
      sku: fields['sku']?.toString() ?? id,
      barcode: fields['barcode'] as String?,
      price: (fields['price'] as num?)?.toDouble() ?? 0,
      unitLabel: fields['unitLabel']?.toString() ?? '1 pc',
      available: stock.ceil(),
      imageUrl: fields['imageUrl'] as String?,
    );
    entries.add({
      'localId': id,
      'kind': kind,
      'fields': fields,
      'stock': stock,
      'posProduct': _toJson(localProduct),
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await savePendingProducts(entries);
    final catalog =
        (await readCatalog()).where((item) => item.id != id).toList();
    await saveCatalog(catalog);
  }

  Future<void> removePendingProduct(String localId) async {
    final entries = (await readPendingProducts())
        .where((entry) => entry['localId'] != localId)
        .toList(growable: false);
    await savePendingProducts(entries);
  }

  Future<void> setPendingProductError(String localId, String message) async {
    final entries = (await readPendingProducts()).toList();
    final index = entries.indexWhere((entry) => entry['localId'] == localId);
    if (index < 0) return;
    entries[index] = {...entries[index], 'syncError': message};
    await savePendingProducts(entries);
  }

  Future<List<PosProduct>> searchCatalog(String query) async {
    final products = await readCatalog();
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          (product.barcode?.toLowerCase().contains(normalized) ?? false);
    }).toList(growable: false);
  }

  Map<String, dynamic> _toJson(PosProduct product) => {
        'id': product.id,
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'price': product.price,
        'unitLabel': product.unitLabel,
        'available': product.available,
        'imageUrl': product.imageUrl,
      };
}
