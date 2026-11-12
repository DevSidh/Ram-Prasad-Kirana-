import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/pos_models.dart';

import 'admin_api_service.dart';
import 'api_service.dart';
import 'local_billing_store.dart';
import 'local_pos_database.dart';
import 'offline_pos_store.dart';
import 'room_inventory_service.dart';

class LocalBillingSync extends ChangeNotifier {
  LocalBillingSync(
      {required this.api,
      required this.ownerId,
      this.store = const LocalBillingStore(),
      this.catalogStore,
      this.refreshStock,
      this.onSynced});

  final ApiService api;
  final String ownerId;
  final LocalBillingStore store;
  final OfflinePosStore? catalogStore;
  final Future<void> Function(Map<String, dynamic> record)? refreshStock;
  final Future<void> Function()? onSynced;
  bool running = false;
  bool? online;
  int pending = 0;
  int localOnly = 0;
  int stockPending = 0;
  DateTime? lastSync;
  String? error;
  String? backupError;
  List<Map<String, dynamic>> conflicts = const [];
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _deltaSyncUnsupported = false;
  bool _disposed = false;

  void start() {
    if (!Platform.isWindows) return;
    unawaited(synchronize());
    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen((results) {
      if (_disposed ||
          !results.any((result) => result != ConnectivityResult.none)) {
        return;
      }
      unawaited(synchronize());
    });
    _timer ??= Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(synchronize());
    });
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> synchronize({bool retryConflicts = false}) async {
    if (running || _disposed || ownerId.isEmpty) return;
    running = true;
    var acknowledged = 0;
    var referenceDataChanged = false;
    error = null;
    _changed();
    try {
      final entries = await store.records();
      final candidates = entries.where((entry) =>
          entry.record['ownerId'] == ownerId &&
          (entry.record['syncState'] == 'pending' ||
              (retryConflicts && entry.record['syncState'] == 'conflict')));
      final offlineStore = catalogStore ?? OfflinePosStore(billingStore: store);
      final adminApi = AdminApiService(api, offlineStore: offlineStore);
      if (candidates.isEmpty) {
        // Release a dead connection quickly so the periodic retry can
        // reconnect instead of leaving the panel unverified indefinitely.
        await api.get('/health').timeout(const Duration(seconds: 8));
      }
      for (final entry in candidates) {
        if (_disposed) break;
        try {
          final payload = entry.record['uploadPayload'];
          if (payload is! Map<String, dynamic>) {
            throw const ApiResponseException(
                'This bill has no valid upload snapshot.',
                statusCode: 409);
          }
          final response = await api.post('/admin/billing/sales', payload);
          if (response is! Map<String, dynamic> ||
              response['sale'] is! Map<String, dynamic>) {
            throw const FormatException(
                'The server did not return the synchronized bill.');
          }
          final serverRecord = response['sale'] as Map<String, dynamic>;
          final verified = PosSale.fromJson(serverRecord);
          if (verified.receiptNumber !=
                  'POS-${entry.record['idempotencyKey'].toString().toUpperCase()}' ||
              (verified.total - (entry.record['total'] as num).toDouble())
                      .abs() >
                  0.001 ||
              verified.status == 'CANCELLED') {
            throw const ApiResponseException(
                'The matching server bill requires review. The local original was not changed.',
                statusCode: 409);
          }
          // Refresh all affected stock snapshots before removing local deductions.
          // A timeout here retains the request key; the server replay is harmless.
          if (refreshStock != null) {
            await refreshStock!(entry.record);
          } else {
            for (final item
                in (entry.record['items'] as List).whereType<Map>()) {
              if (item['productId']?.toString().startsWith('manual-') == true) {
                continue;
              }
              final refreshed = await adminApi
                  .searchPosProducts(item['sku']?.toString() ?? '');
              if (!refreshed
                  .any((product) => product.id == item['productId'])) {
                throw const FormatException(
                    'Bill saved on server, but its stock snapshot could not be refreshed. The same request will be retried safely.');
              }
              await const OfflinePosStore().mergeCatalog(refreshed);
            }
          }
          if (entry.record['roomPicks'] != null) {
            // Refresh the room baseline before a later offline checkout.
            await RoomInventoryService(
                    adminApi, OfflinePosStore(billingStore: store))
                .load(
                    allowCached: false,
                    productIds: (entry.record['items'] as List)
                        .cast<Map>()
                        .map((item) => item['productId'] as String)
                        .where((id) => !id.startsWith('manual-'))
                        .toSet()
                        .toList());
          }
          await store.setSyncResult(entry.file,
              state: 'synced', serverSale: serverRecord);
          acknowledged++;
        } on ApiResponseException catch (failure) {
          if ([400, 403, 404, 409].contains(failure.statusCode)) {
            await store.setSyncResult(entry.file,
                state: 'conflict', error: failure.message);
          } else {
            rethrow;
          }
        }
      }
      // Computer-only invoices/customers never leave the computer. Share only
      // the inventory quantities so other tills see the same remaining stock.
      for (final entry in entries.where((entry) =>
          entry.record['ownerId'] == ownerId &&
          entry.record['syncState'] == 'local_only' &&
          entry.record['roomPicks'] is List &&
          entry.record['roomStockSyncedAt'] == null &&
          (retryConflicts ||
              entry.record['roomStockSyncState'] != 'conflict'))) {
        if (_disposed) break;
        try {
          final quantities = <String, int>{};
          final skus = <String, String>{};
          for (final item in (entry.record['items'] as List).cast<Map>()) {
            final id = item['productId'] as String;
            if (id.startsWith('manual-')) continue;
            quantities[id] = (quantities[id] ?? 0) +
                ((item['weightGrams'] ?? item['quantity']) as num).toInt();
            skus[id] = item['sku'] as String;
          }
          if (quantities.isEmpty) {
            await store.setRoomStockSyncResult(entry.file, synced: true);
            continue;
          }
          final localIds = quantities.keys
              .where((id) => RegExp(r'^(offline|wholesale)-\d+$').hasMatch(id))
              .toSet();
          if (localIds.isNotEmpty) {
            await adminApi.syncPendingOfflineProducts();
            if ((await offlineStore.readPendingProducts())
                .any((product) => localIds.contains(product['localId']))) {
              throw const ApiResponseException(
                  'Resolve the offline product catalogue conflict before sharing this bill stock.',
                  statusCode: 409);
            }
          }
          final response = await api.post('/admin/billing/rooms/local-sales', {
            'requestId': entry.record['idempotencyKey'],
            'items': [
              for (final item in quantities.entries)
                {
                  'productId': item.key,
                  'quantity': item.value,
                  'sku': skus[item.key]
                }
            ],
            'roomPicks': entry.record['roomPicks'],
          });
          if (response is! Map<String, dynamic> ||
              response['success'] != true ||
              response['requestId'] != entry.record['idempotencyKey'] ||
              response['productIds'] is! Map) {
            throw const FormatException(
                'The server did not confirm the stock reference. Retry synchronization.');
          }
          final resolvedIds =
              Map<String, dynamic>.from(response['productIds'] as Map);
          if (refreshStock != null) {
            await refreshStock!(entry.record);
          } else {
            for (final item in (entry.record['items'] as List).cast<Map>()) {
              if (item['productId']?.toString().startsWith('manual-') == true) {
                continue;
              }
              final products = await adminApi
                  .searchPosProducts(item['sku'] as String? ?? '');
              if (!products
                  .any((p) => p.id == resolvedIds[item['productId']])) {
                throw const FormatException(
                    'Stock snapshot could not be refreshed. Retry synchronization.');
              }
              await offlineStore.mergeCatalog(products);
            }
          }
          if (localIds.isNotEmpty) {
            await offlineStore.saveCatalog(
                (await offlineStore.readCatalogBaseline())
                    .where((p) => !localIds.contains(p.id))
                    .toList());
          }
          await RoomInventoryService(adminApi, offlineStore).load(
              allowCached: false,
              productIds: resolvedIds.values.cast<String>().toList());
          await store.setRoomStockSyncResult(entry.file, synced: true);
          acknowledged++;
        } on ApiResponseException catch (failure) {
          if ([400, 403, 404, 409].contains(failure.statusCode)) {
            await store.setRoomStockSyncResult(entry.file,
                error: failure.message);
          } else {
            rethrow;
          }
        }
      }
      if (Platform.isWindows &&
          !_deltaSyncUnsupported &&
          store.rootPath.replaceAll('\\', '/').toLowerCase() ==
              'c:/ramprasad store/bills') {
        final localDatabase = await LocalPosDatabase.defaultInstance();
        const tables = [
          'products',
          'wholesale_products',
          'drinks_menu',
          'customers',
          'bills',
          'refunds',
          'pending_cash',
        ];
        final cursors = <String, DateTime?>{};
        for (final table in tables) {
          cursors[table] = await localDatabase.lastSyncedAt(table);
        }
        try {
          final batch = await adminApi.getOfflinePosSync(cursors);
          referenceDataChanged = const [
            'products',
            'wholesaleProducts',
            'drinks',
            'customers',
            'bills',
            'refunds',
            'pendingCash',
          ].any((key) => (batch[key] as List?)?.isNotEmpty == true);
          await localDatabase.applySyncBatch(batch);
        } on ApiResponseException catch (failure) {
          if (failure.statusCode != 404) rethrow;
          await localDatabase.clearSyncMetadata(tables);
          OfflinePosStore.invalidateFullRefresh();
          _deltaSyncUnsupported = true;
          error = null;
        }
      }
      online = true;
      lastSync = DateTime.now();
      await store.writeJson(File('${store.rootPath}/.meta/sync.json'), {
        'lastSync': lastSync!.toUtc().toIso8601String(),
      });
    } catch (failure) {
      online = failure is ApiNetworkException || failure is ApiTimeoutException
          ? false
          : null;
      // A background health/sync timeout is an offline state, not a failed
      // invoice operation. Keep the reconnect indicator visible without
      // leaving a persistent red error after the invoice dialog closes.
      error = failure is ApiTimeoutException ? null : failure.toString();
    } finally {
      try {
        final entries = await store.records();
        if (entries
            .any((entry) => entry.record['_recoveredFromBackup'] == true)) {
          error ??=
              'A damaged local bill was recovered from its previous copy. Review its payment history before recording more payments.';
        }
        final owned =
            entries.where((entry) => entry.record['ownerId'] == ownerId);
        pending = owned
            .where((entry) => entry.record['syncState'] == 'pending')
            .length;
        localOnly = entries
            .where((entry) =>
                entry.record['syncState'] == null ||
                entry.record['syncState'] == 'local_only')
            .length;
        stockPending = owned
            .where((entry) =>
                entry.record['syncState'] == 'local_only' &&
                entry.record['roomPicks'] is List &&
                entry.record['roomStockSyncedAt'] == null)
            .length;
        conflicts = owned
            .where((entry) =>
                entry.record['syncState'] == 'conflict' ||
                entry.record['roomStockSyncState'] == 'conflict')
            .map((entry) => entry.record)
            .toList(growable: false);
        if (lastSync == null) {
          final metadata = File('${store.rootPath}/.meta/sync.json');
          if (await metadata.exists()) {
            lastSync = DateTime.tryParse(
                (await store.readJson(metadata))['lastSync']?.toString() ?? '');
          }
        }
      } catch (failure) {
        error ??= failure.toString();
      }
      running = false;
      _changed();
    }
    if ((acknowledged > 0 || referenceDataChanged) &&
        !_disposed &&
        onSynced != null) {
      await onSynced!();
    }
    if (!_disposed) await _dailyBackup();
  }

  Future<void> _dailyBackup() async {
    try {
      final now = DateTime.now();
      final key =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File(
          '${Directory(store.rootPath).parent.path}/backups/local-$key.fsbak');
      var changed = !await file.exists();
      final backupTime = changed ? DateTime(1970) : await file.lastModified();
      final root = Directory(store.rootPath);
      if (await root.exists()) {
        await for (final entity
            in root.list(recursive: true, followLinks: false)) {
          if (entity is File &&
              !entity.path.contains(
                  '${Platform.pathSeparator}.meta${Platform.pathSeparator}') &&
              !entity.path.endsWith('.bak') &&
              !entity.path.endsWith('.lock') &&
              !entity.path.endsWith('.tmp') &&
              (await entity.lastModified()).isAfter(backupTime)) {
            changed = true;
            break;
          }
        }
      }
      if (changed) await store.createBackup(file);
      backupError = null;
    } catch (failure) {
      backupError = failure.toString();
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_connectivitySubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
