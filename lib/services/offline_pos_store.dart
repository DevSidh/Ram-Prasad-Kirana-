import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/admin_models.dart';
import '../models/pos_models.dart';
import '../models/stock_summary.dart';
import 'local_billing_store.dart';
import 'local_pos_database.dart';
import 'inventory_changes.dart';

/// Persistent local POS catalog used by the Windows billing screen when the
/// server cannot be reached. The server remains the source of truth online.
class OfflinePosStore {
  const OfflinePosStore(
      {this.storageDirectory,
      this.billingStore = const LocalBillingStore(),
      this.useLocalStock});
  final Directory? storageDirectory;
  final LocalBillingStore billingStore;
  final bool? useLocalStock;
  static final _catalogs = <String, _CatalogSnapshot>{};
  static final _refreshes = <String, Future<bool>>{};
  static final _refreshedAt = <String, DateTime>{};
  static bool _forceRefreshAll = false;

  /// Share one full refresh across bill windows, then reuse it for five minutes.
  /// Exact stock/prices are still checked by the sale transaction.
  Future<bool> refreshCatalogIfNeeded(Future<List<PosProduct>> Function() load,
      {bool force = false}) async {
    if (kIsWeb) return false;
    final file = await _catalogFile();
    final key = file.absolute.path;
    final inFlight = _refreshes[key];
    if (inFlight != null) return inFlight;
    final localDatabase = Platform.isWindows ? await _localDatabase() : null;
    if (localDatabase != null && !force && !_forceRefreshAll) {
      final persistedCursor = await localDatabase.lastSyncedAt('products');
      // A cursor means that a prior catalogue sync succeeded; it must not
      // suppress every later refresh.  Otherwise items imported after the
      // first install can never reach the billing search list.
      if (persistedCursor != null &&
          DateTime.now().toUtc().difference(persistedCursor) <
              const Duration(minutes: 5)) {
        return false;
      }
    }
    final last = _refreshedAt[key];
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 5) &&
        await file.exists()) {
      return false;
    }
    // Schedule the loader after publishing the in-flight future. This closes
    // the small race where two invoice windows could both start a refresh
    // before `_refreshes[key]` was assigned.
    final request = Future<bool>(() async {
      final startedAt = DateTime.now().toUtc();
      final products = await load();
      await saveCatalog(products);
      if (localDatabase != null) {
        for (final table in ['products', 'wholesale_products']) {
          await localDatabase.setLastSyncedAt(table, startedAt);
        }
      }
      if (_refreshedAt.length >= 4) {
        _refreshedAt.remove(_refreshedAt.keys.first);
      }
      _refreshedAt[key] = DateTime.now();
      _forceRefreshAll = false;
      return true;
    });
    _refreshes[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_refreshes[key], request)) _refreshes.remove(key);
    }
  }

  static void invalidateFullRefresh() {
    _refreshedAt.clear();
    _forceRefreshAll = true;
    InventoryChanges.notify();
  }

  Future<File> _catalogFile() async {
    final directory =
        storageDirectory ?? await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/catalog.json');
  }

  Future<LocalPosDatabase> _localDatabase() async {
    final catalog = await _catalogFile();
    final path = '${catalog.parent.path}${Platform.pathSeparator}'
        'faststore_pos.sqlite';
    return LocalPosDatabase.atPath(path);
  }

  Future<File> _pendingProductsFile() async {
    final directory =
        storageDirectory ?? await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/pending_products.json');
  }

  Future<File> _categoriesFile() async {
    final directory =
        storageDirectory ?? await getApplicationSupportDirectory();
    final offlineDirectory = Directory('${directory.path}/offline_pos');
    await offlineDirectory.create(recursive: true);
    return File('${offlineDirectory.path}/categories.json');
  }

  Future<File> _dashboardFile() async {
    final directory =
        storageDirectory ?? await getApplicationSupportDirectory();
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

  Future<double> readOfflineSalesTotal() => _readOfflineSalesTotal();

  /// Original server quantities, for rebuilding a cache after a partial refresh.
  /// Financial validation must use readCatalog(freshStock: true) instead.
  Future<List<PosProduct>> readCatalogBaseline() => _readRawCatalog();

  Future<double> readOfflineSalesTotalForDay(String day) =>
      _readOfflineSalesTotal(day: day);

  Future<double> _readOfflineSalesTotal({String? day}) async {
    if (kIsWeb) return 0;
    final directory = Directory(billingStore.rootPath);
    if (!await directory.exists()) return 0;
    var total = 0.0;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        try {
          final decoded = await billingStore.readJson(entity);
          // This card reports sales created on this computer, including bills
          // that have already synchronized. Excluding synced records made the
          // offline amount fall back to zero after background sync completed.
          if (decoded['status'] == 'CANCELLED') {
            continue;
          }
          if (day != null) {
            final date = DateTime.tryParse(
                    '${decoded['date'] ?? decoded['createdAt'] ?? ''}')
                ?.toUtc()
                .add(const Duration(hours: 5, minutes: 45));
            if (date == null) continue;
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            if (key != day) continue;
          }
          final amount = decoded['total'];
          total += amount is num
              ? amount.toDouble()
              : double.tryParse(amount?.toString() ?? '') ?? 0;
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
    final directory = Directory(billingStore.rootPath);
    if (!await directory.exists()) return const [];
    final sales = <PosSale>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        try {
          final decoded = await billingStore.readJson(entity);
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
            id: decoded['serverSaleId']?.toString() ?? 'local-$invoiceNumber',
            receiptNumber:
                decoded['serverReceiptNumber']?.toString() ?? invoiceNumber,
            invoiceNumber:
                decoded['serverInvoiceNumber']?.toString() ?? invoiceNumber,
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

  Future<List<PosProduct>> readCatalog({bool freshStock = false}) async =>
      projectLocalStock(await _readRawCatalog(fresh: freshStock),
          freshStock: freshStock);

  /// A conservative local estimate; central availability is a separate value.
  Future<List<PosProduct>> projectLocalStock(List<PosProduct> products,
      {bool freshStock = false}) async {
    if (kIsWeb || !(useLocalStock ?? Platform.isWindows)) return products;
    if (products.isEmpty) return products;
    final deductions = freshStock
        ? await billingStore.stockDeductions()
        : await billingStore.stockDeductionsForDisplay();
    final prices = await billingStore.pendingCataloguePrices();
    return products
        .map((product) => PosProduct(
              id: product.id,
              name: product.name,
              sku: product.sku,
              barcode: product.barcode,
              price: prices[product.id] ?? product.price,
              unitLabel: product.unitLabel,
              available: product.isUnlimited
                  ? product.available
                  : (product.available - (deductions[product.id] ?? 0))
                      .clamp(0, product.available)
                      .toInt(),
              isUnlimited: product.isUnlimited,
              imageUrl: product.imageUrl,
            ))
        .toList(growable: false);
  }

  Future<List<PosProduct>> _readRawCatalog({bool fresh = false}) async {
    if (kIsWeb) return const [];
    try {
      // The JSON snapshot is the recovery authority. If its primary file is
      // interrupted/corrupt, do not let a newer SQLite cache mask the backup
      // that contains the last complete catalogue.
      final file = await _catalogFile();
      var primaryHealthy = true;
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw);
          primaryHealthy = decoded is Map && decoded['products'] is List;
        } catch (_) {
          primaryHealthy = false;
        }
      }
      final localDatabase = Platform.isWindows ? await _localDatabase() : null;
      if (localDatabase != null && primaryHealthy) {
        final localProducts = await localDatabase.readCatalog();
        if (localProducts.isNotEmpty ||
            await localDatabase.lastSyncedAt('products') != null) {
          return localProducts;
        }
      }
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return const [];
      final cached = _catalogs[file.absolute.path];
      if (!fresh && cached != null && cached.matches(stat)) {
        return cached.products;
      }
      final decoded = await const LocalBillingStore().readJson(file);
      if (decoded['products'] is! List) {
        return const [];
      }
      var products = (decoded['products'] as List)
          .whereType<Map<String, dynamic>>()
          .map(PosProduct.fromJson)
          .toList(growable: false);
      final pending = await readPendingProducts();
      final normalized = {
        for (final entry in pending)
          if (entry['posProduct'] is Map<String, dynamic>)
            entry['localId'] as String: pendingProductSnapshot(entry)
      };
      if (normalized.isNotEmpty) {
        products =
            products.map((p) => normalized[p.id] ?? p).toList(growable: false);
      }
      if (localDatabase != null) {
        try {
          await localDatabase.replaceCatalog(products);
        } catch (_) {
          // The JSON snapshot remains the recovery source if SQLite is unavailable.
        }
      }
      // Recovery copies must remain observable; never cache a broken primary.
      if (decoded['_recoveredFromBackup'] != true && products.length <= 20000) {
        if (_catalogs.length >= 4) _catalogs.remove(_catalogs.keys.first);
        _catalogs[file.absolute.path] = _CatalogSnapshot(stat, products);
      }
      return products;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCatalog(List<PosProduct> products) async {
    if (kIsWeb) return;
    final file = await _catalogFile();
    await LocalBillingStore(rootPath: file.parent.path)
        .withLock(() => _writeCatalog(file, products));
  }

  Future<void> _writeCatalog(File file, List<PosProduct> products) async {
    final pending = await readPendingProducts();
    final combined = <String, PosProduct>{
      for (final product in products) product.id: product,
      for (final entry in pending)
        if (entry['posProduct'] is Map<String, dynamic>)
          (entry['posProduct'] as Map<String, dynamic>)['id'] as String:
              pendingProductSnapshot(entry),
    };
    await const LocalBillingStore().writeJson(file, {
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'products': combined.values.map(_toJson).toList(growable: false),
    });
    if (Platform.isWindows) {
      try {
        final localDatabase = await _localDatabase();
        await localDatabase
            .replaceCatalog(combined.values.toList(growable: false));
      } catch (error) {
        debugPrint('Unable to update the local POS SQLite catalog: $error');
      }
    }
    _catalogs.remove(file.absolute.path);
  }

  /// Adds partial catalog results without deleting products cached earlier.
  /// Use this for paginated admin screens and server-side search results.
  Future<void> mergeCatalog(List<PosProduct> products) async {
    if (kIsWeb || products.isEmpty) return;
    final file = await _catalogFile();
    await LocalBillingStore(rootPath: file.parent.path).withLock(() async {
      final existing = await _readRawCatalog();
      final byId = {for (final product in existing) product.id: product};
      if (products
          .every((product) => _sameSnapshot(byId[product.id], product))) {
        return; // An unchanged lookup is not a catalogue mutation.
      }
      final merged = <String, PosProduct>{
        ...byId,
        for (final product in products) product.id: product,
      };
      await _writeCatalog(file, merged.values.toList(growable: false));
    });
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
      available: kind != 'wholesale' &&
              StockSummary.isWeight(fields['unitLabel']?.toString() ?? '')
          ? (stock * 1000).round()
          : stock.ceil(),
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
        (await _readRawCatalog()).where((item) => item.id != id).toList();
    await saveCatalog(catalog);
  }

  Future<void> removePendingProduct(String localId) async {
    final entries = (await readPendingProducts())
        .where((entry) => entry['localId'] != localId)
        .toList(growable: false);
    await savePendingProducts(entries);
  }

  /// Pending retail stock uses the same gram-based representation as the API.
  /// This also repairs cached pre-room catalog entries without changing bills.
  static PosProduct pendingProductSnapshot(Map<String, dynamic> entry) {
    final json = Map<String, dynamic>.from(entry['posProduct'] as Map);
    final stock = entry['stock'];
    if (stock is num &&
        entry['kind'] != 'wholesale' &&
        StockSummary.isWeight(json['unitLabel']?.toString() ?? '')) {
      json['available'] = (stock * 1000).round();
    }
    return PosProduct.fromJson(json);
  }

  Future<void> setPendingProductError(String localId, String message) async {
    final entries = (await readPendingProducts()).toList();
    final index = entries.indexWhere((entry) => entry['localId'] == localId);
    if (index < 0) return;
    entries[index] = {...entries[index], 'syncError': message};
    await savePendingProducts(entries);
  }

  Future<List<PosProduct>> searchCatalog(String query) async {
    final products = await _readRawCatalog();
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return projectLocalStock(products);
    // Filter before projecting stock; never allocate the entire projected
    // catalogue for a lookup that displays one product.
    return projectLocalStock(products.where((product) {
      return product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          (product.barcode?.toLowerCase().contains(normalized) ?? false);
    }).toList(growable: false));
  }

  Future<List<AdminCustomer>> readCustomers() async {
    if (kIsWeb || !Platform.isWindows) return const [];
    try {
      return await (await _localDatabase()).readCustomers();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomers(List<AdminCustomer> customers) async {
    if (kIsWeb || !Platform.isWindows || customers.isEmpty) return;
    try {
      await (await _localDatabase()).saveCustomers(customers);
    } catch (_) {}
  }

  Future<PosSalesPage?> readCachedBillsPage({
    int page = 1,
    int pageSize = 50,
  }) async {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      return await (await _localDatabase())
          .readBillsPage(page: page, pageSize: pageSize);
    } catch (_) {
      return null;
    }
  }

  Future<PosSalesPage?> readCachedPendingPayments({
    int page = 1,
    int pageSize = 50,
  }) async {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      return await (await _localDatabase())
          .readPendingPayments(page: page, pageSize: pageSize);
    } catch (_) {
      return null;
    }
  }

  Future<List<PosRefund>?> readCachedRefunds() async {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      return await (await _localDatabase()).readRefunds();
    } catch (_) {
      return null;
    }
  }

  static bool _sameSnapshot(PosProduct? a, PosProduct b) =>
      a != null &&
      a.id == b.id &&
      a.name == b.name &&
      a.sku == b.sku &&
      a.barcode == b.barcode &&
      a.price == b.price &&
      a.unitLabel == b.unitLabel &&
      a.available == b.available &&
      a.isUnlimited == b.isUnlimited &&
      a.imageUrl == b.imageUrl;

  Map<String, dynamic> _toJson(PosProduct product) => {
        'id': product.id,
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'price': product.price,
        'unitLabel': product.unitLabel,
        'available': product.available,
        'isUnlimited': product.isUnlimited,
        'imageUrl': product.imageUrl,
      };
}

class _CatalogSnapshot {
  _CatalogSnapshot(this.stat, List<PosProduct> products)
      : products = List.unmodifiable(products);
  final FileStat stat;
  final List<PosProduct> products;
  bool matches(FileStat next) =>
      stat.size == next.size &&
      stat.modified == next.modified &&
      stat.changed == next.changed;
}
