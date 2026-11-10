import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/pos_models.dart';
import 'admin_api_service.dart';
import 'api_service.dart';
import 'billing_workbook.dart';
import 'catalogue_price_workbook.dart';
import 'offline_pos_store.dart';
import 'inventory_changes.dart';

/// Windows admin-only bridge. The trusted baseline/outbox stays outside Excel;
/// stock, names, IDs, and categories can never be changed through this workbook.
class CatalogueExcelSync extends ChangeNotifier {
  CatalogueExcelSync(this.api, this.store, {required this.ownerId});
  final AdminApiService api;
  final OfflinePosStore store;
  final String ownerId;
  Timer? _timer;
  bool busy = false;
  bool _disposed = false;
  String status = 'Preparing product price workbook';
  String get directory => '${store.billingStore.rootPath}/excel';
  String get path => '$directory/FastStore_Product_Prices.xlsx';
  File get _stateFile => File('$directory/price-sync-$ownerId.json');

  void start() {
    InventoryChanges.revision.addListener(_onCatalogueChanged);
    unawaited(synchronize());
    _timer = Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(synchronize()));
  }

  void _onCatalogueChanged() {
    unawaited(synchronize());
  }

  @override
  void dispose() {
    _disposed = true;
    InventoryChanges.revision.removeListener(_onCatalogueChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> state) async {
    await _stateFile.parent.create(recursive: true);
    final tmp = File('${_stateFile.path}.pending');
    await tmp.writeAsString(jsonEncode(state), flush: true);
    await tmp.rename(_stateFile.path);
  }

  Future<void> synchronize({bool useAppPrices = false}) async {
    if (busy || _disposed || ownerId.isEmpty) return;
    busy = true;
    _changed();
    final file = File(path);
    var imported = false;
    try {
      await file.parent.create(recursive: true);
      var state = await _stateFile.exists()
          ? Map<String, dynamic>.from(
              jsonDecode(await _stateFile.readAsString()) as Map)
          : <String, dynamic>{};
      if (useAppPrices && await file.exists()) {
        await file.copy(
            '$path.before-reset-${DateTime.now().millisecondsSinceEpoch}.bak');
        state.remove('pending');
        state.remove('conflict');
      }
      if (state['conflict'] == true && !useAppPrices) {
        throw StateError(
            'A price changed in the app after Excel was exported. Import paused. Use app prices to refresh the workbook; an Excel backup will be kept.');
      }
      final baseline = Map<String, dynamic>.from(state['prices'] as Map? ?? {});
      if (!useAppPrices && state['pending'] == null && await file.exists()) {
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        if (hash != state['hash']) {
          if (baseline.isEmpty) {
            throw StateError(
                'No trusted price baseline for this workbook. Use app prices to create a fresh linked copy; the existing file will be backed up.');
          }
          final rows = await compute(readCataloguePrices, bytes);
          final changes = <Map<String, dynamic>>[];
          for (final row in rows) {
            final id = row['id'] as String;
            if (!baseline.containsKey(id)) {
              throw FormatException(
                  'Unknown Product ID $id. No prices imported.');
            }
            final price = (row['price'] as num).toDouble();
            if ((price * 100).round() !=
                ((baseline[id] as num) * 100).round()) {
              changes.add({
                'productId': id,
                'expectedPrice': baseline[id],
                'price': price
              });
            }
          }
          if (changes.length > 100) {
            throw StateError(
                'Edit up to 100 prices per save, then sync before editing more. No prices imported.');
          }
          if (changes.isNotEmpty) {
            state['pending'] = {
              'requestId': const Uuid().v4(),
              'changes': changes
            };
            await _save(
                state); // Durable before any request; retries use same key.
          }
        }
      }
      if (state['pending'] is Map) {
        final pending = Map<String, dynamic>.from(state['pending'] as Map);
        final changes = (pending['changes'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        try {
          await api.applyCataloguePriceChanges(
              pending['requestId'] as String, changes);
          imported = true;
        } on ApiResponseException catch (error) {
          if (error.statusCode == 409) {
            state['conflict'] = true;
            await _save(state);
          }
          rethrow;
        }
        for (final change in changes) {
          baseline[change['productId'] as String] = change['price'];
        }
        state['prices'] = baseline;
        state.remove('pending');
        await _save(state);
      }
      // All requests run in the background, never in a screen's build/open path.
      final products = await api.getAllProducts();
      final wholesale = await api.getAllWholesaleItems();
      if (_disposed) return;
      final latest = <String, double>{};
      final sheets = <String, List<List<Object?>>>{
        for (final title in ['Products', 'Wholesale', 'Drinks'])
          title: [
            [
              'Product ID',
              'SKU',
              'Name',
              'Price NPR',
              'Unit',
              'Available',
              'Category'
            ]
          ],
      };
      final catalogue = <PosProduct>[];
      for (final p in products.where((p) => p.isActive)) {
        latest[p.id] = p.price;
        sheets[p.isVendingDrink ? 'Drinks' : 'Products']!.add([
          p.id,
          p.sku,
          p.name,
          p.price,
          p.unitLabel,
          p.availableStock,
          p.categoryName
        ]);
        catalogue.add(PosProduct(
            id: p.id,
            name: p.name,
            sku: p.sku,
            barcode: p.barcode,
            price: p.price,
            unitLabel: p.unitLabel,
            available: p.posStockUnits,
            imageUrl: p.imageUrl));
      }
      for (final p in wholesale.where((p) => p.isActive)) {
        final id = 'wholesale-${p.id}';
        latest[id] = p.price;
        sheets['Wholesale']!.add(
            [id, p.sku, p.name, p.price, p.unitLabel, p.stock, p.categoryName]);
        catalogue.add(PosProduct(
            id: id,
            name: p.name,
            sku: p.sku,
            barcode: null,
            price: p.price,
            unitLabel: p.unitLabel,
            available: p.stock,
            imageUrl: p.imageUrl));
      }
      await store.mergeCatalog(catalogue);
      if (imported) InventoryChanges.notify();
      String? validatedHash = await file.exists()
          ? sha256.convert(await file.readAsBytes()).toString()
          : null;
      // Re-read after network calls: never overwrite a workbook saved meanwhile.
      if (!useAppPrices && await file.exists()) {
        final bytes = await file.readAsBytes();
        validatedHash = sha256.convert(bytes).toString();
        if (sha256.convert(bytes).toString() != state['hash']) {
          final rows = await compute(readCataloguePrices, bytes);
          final unresolved = rows.any((row) =>
              !baseline.containsKey(row['id']) ||
              (((row['price'] as num) * 100).round() !=
                  ((baseline[row['id']] as num) * 100).round()));
          if (unresolved) {
            status = 'New Excel edits waiting for the next sync';
            return;
          }
        }
      }
      final catalogueHash =
          sha256.convert(utf8.encode(jsonEncode(sheets))).toString();
      if (!useAppPrices &&
          validatedHash == state['hash'] &&
          catalogueHash == state['catalogueHash']) {
        status = 'Prices synced. Edit Price NPR, save and close Excel.';
        return;
      }
      final bytes = await compute(buildBillingWorkbook, sheets);
      final currentHash = await file.exists()
          ? sha256.convert(await file.readAsBytes()).toString()
          : null;
      if (currentHash != validatedHash) {
        status =
            'Excel changed while exporting. Your edits were retained; retrying next sync.';
        return;
      }
      // Avoid replacing identical content and touching the user's file needlessly.
      if (currentHash != sha256.convert(bytes).toString()) {
        if (await file.exists()) await file.copy('$path.bak');
        final tmp = File('$path.pending');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp
            .rename(path); // Open Excel file => retry later, never delete it.
      }
      state = {
        'prices': latest,
        'hash': sha256.convert(bytes).toString(),
        'catalogueHash': catalogueHash,
        'updatedAt': DateTime.now().toUtc().toIso8601String()
      };
      await _save(state);
      status = 'Prices synced. Edit Price NPR, save and close Excel.';
    } catch (error) {
      status = error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '');
    } finally {
      busy = false;
      _changed();
    }
  }
}
