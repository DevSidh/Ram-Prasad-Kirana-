import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/room_inventory.dart';
import '../models/stock_summary.dart';
import 'admin_api_service.dart';
import 'offline_pos_store.dart';
import 'api_service.dart';

/// Shared stock is authoritative online. Computer-only bills are projected on
/// this computer; queued bills stop being projected after server acknowledgement.
class RoomInventoryService {
  const RoomInventoryService(this.api, this.store);
  static final _localSnapshots = <String, RoomInventorySnapshot>{};
  final AdminApiService api;
  final OfflinePosStore store;
  bool get _usesLocal => !kIsWeb && (store.useLocalStock ?? Platform.isWindows);
  File get _file => File('${store.billingStore.rootPath}/inventory/rooms.json');

  Future<RoomInventorySnapshot?> loadLocalIfAvailable(
      {List<String>? productIds}) async {
    if (kIsWeb || !(store.useLocalStock ?? Platform.isWindows)) return null;
    final key = _file.absolute.path;
    final cached = _localSnapshots[key];
    if (cached != null) return cached;
    if (!await _file.exists()) return null;
    try {
      final json = await store.billingStore.readJson(_file);
      final snapshot =
          await project(RoomInventorySnapshot.fromJson(json, cached: true));
      _localSnapshots[key] = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<RoomInventorySnapshot> load(
      {List<String>? productIds,
      bool offline = false,
      bool allowCached = true}) async {
    Map<String, dynamic> json;
    var cached = offline;
    if (offline) {
      json = await store.billingStore.readJson(_file);
    } else {
      try {
        json = await api.getRoomInventory(productIds: productIds);
        if (_usesLocal) {
          await store.billingStore.withLock(() async {
            if (productIds != null && await _file.exists()) {
              final old = await store.billingStore.readJson(_file);
              json = {
                ...json,
                'stocks': [
                  ...(old['stocks'] as List).where(
                      (row) => !productIds.contains((row as Map)['productId'])),
                  ...json['stocks'] as List
                ],
                'totals': [
                  ...(old['totals'] as List).where(
                      (row) => !productIds.contains((row as Map)['productId'])),
                  ...json['totals'] as List
                ],
                'products': [
                  ...(old['products'] as List? ?? [])
                      .where((row) => !productIds.contains((row as Map)['id'])),
                  ...json['products'] as List? ?? [],
                ],
              };
            }
            await store.billingStore.writeJson(_file, json);
            _localSnapshots.remove(_file.absolute.path);
          });
        }
      } on ApiNetworkException {
        if (!allowCached || !_usesLocal) rethrow;
        json = await store.billingStore.readJson(_file);
        cached = true;
      } on ApiTimeoutException {
        if (!allowCached || !_usesLocal) rethrow;
        json = await store.billingStore.readJson(_file);
        cached = true;
      }
    }
    final snapshot = RoomInventorySnapshot.fromJson(json, cached: cached);
    if (!kIsWeb) {
      for (final pending in await store.readPendingProducts()) {
        final product = pending['posProduct'];
        if (product is Map<String, dynamic> && product['available'] is num) {
          final normalized = OfflinePosStore.pendingProductSnapshot(pending);
          final count = normalized.available;
          snapshot.totals.putIfAbsent(
              product['id'] as String, () => (total: count, available: count));
          final fields = pending['fields'];
          if (fields is Map && fields['initialRoomAllocations'] is List) {
            final factor = pending['kind'] != 'wholesale' &&
                    StockSummary.isWeight(normalized.unitLabel)
                ? 1000
                : 1;
            snapshot.stocks[normalized.id] = {
              for (final row in fields['initialRoomAllocations'] as List)
                if (row is Map &&
                    row['roomId'] is String &&
                    row['quantity'] is num)
                  row['roomId'] as String:
                      ((row['quantity'] as num) * factor).round(),
            };
          }
          if (!snapshot.products.any((p) => p.id == product['id'])) {
            snapshot.products.add(normalized);
          }
        }
      }
    }
    return project(snapshot);
  }

  Future<RoomInventorySnapshot> project(RoomInventorySnapshot snapshot) async {
    if (kIsWeb || !(store.useLocalStock ?? Platform.isWindows)) return snapshot;
    for (final entry in await store.billingStore.records()) {
      final bill = entry.record;
      if (bill['trackLocalStock'] != true ||
          bill['syncState'] == 'synced' ||
          bill['roomStockSyncedAt'] != null ||
          bill['status'] == 'CANCELLED') {
        continue;
      }
      final picked = (bill['roomPicks'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(RoomPick.fromJson)
          .toList();
      final quantities = <String, int>{};
      for (final item in (bill['items'] as List).cast<Map>()) {
        final id = item['productId']?.toString();
        if (id != null) {
          quantities[id] = (quantities[id] ?? 0) +
              ((item['weightGrams'] ?? item['quantity']) as num).toInt();
        }
      }
      for (final entry in quantities.entries) {
        final total = snapshot.totals[entry.key];
        if (total == null) continue;
        final chosen =
            picked.where((pick) => pick.productId == entry.key).toList();
        if (chosen.isEmpty) {
          // Older local bills have no room information. Use Unassigned first.
          var left = entry.value - snapshot.quantity(entry.key, null);
          for (final id in snapshot.locations.whereType<String>()) {
            if (left <= 0) break;
            final count = snapshot.quantity(entry.key, id);
            final take = left.clamp(0, count);
            left -= take;
            snapshot.stocks[entry.key]?[id] = count - take;
          }
        } else {
          for (final pick in chosen) {
            if (pick.quantity > snapshot.quantity(entry.key, pick.roomId)) {
              snapshot.conflictedProducts.add(entry.key);
            }
          }
          for (final pick in chosen.where((pick) => pick.roomId != null)) {
            final map = snapshot.stocks[entry.key] ??= {};
            map[pick.roomId!] =
                ((map[pick.roomId!] ?? 0) - pick.quantity).clamp(0, 2147483647);
          }
        }
        snapshot.totals[entry.key] = (
          total: (total.total - entry.value).clamp(0, 2147483647),
          available: (total.available - entry.value).clamp(0, 2147483647)
        );
        // A different till may already have sold these units while this one
        // was offline. Keep estimates conservative and flag the discrepancy.
        final roomCounts = snapshot.stocks[entry.key] ?? {};
        var excess = roomCounts.values.fold<int>(0, (sum, q) => sum + q) -
            snapshot.totals[entry.key]!.total;
        if (entry.value > total.total || excess > 0) {
          snapshot.conflictedProducts.add(entry.key);
        }
        for (final id in roomCounts.keys.toList()..sort()) {
          if (excess <= 0) break;
          final take = excess.clamp(0, roomCounts[id]!);
          roomCounts[id] = roomCounts[id]! - take;
          excess -= take;
        }
      }
    }
    return snapshot;
  }
}
