import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/pos_models.dart';

import 'admin_api_service.dart';
import 'api_service.dart';
import 'local_billing_store.dart';
import 'offline_pos_store.dart';

class LocalBillingSync extends ChangeNotifier {
  LocalBillingSync(
      {required this.api,
      required this.ownerId,
      this.store = const LocalBillingStore(),
      this.refreshStock,
      this.onSynced});

  final ApiService api;
  final String ownerId;
  final LocalBillingStore store;
  final Future<void> Function(Map<String, dynamic> record)? refreshStock;
  final Future<void> Function()? onSynced;
  bool running = false;
  bool? online;
  int pending = 0;
  int localOnly = 0;
  DateTime? lastSync;
  String? error;
  String? backupError;
  List<Map<String, dynamic>> conflicts = const [];
  Timer? _timer;
  bool _disposed = false;

  void start() {
    if (!Platform.isWindows) return;
    unawaited(synchronize());
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
    error = null;
    _changed();
    try {
      final entries = await store.records();
      final candidates = entries.where((entry) =>
          entry.record['ownerId'] == ownerId &&
          (entry.record['syncState'] == 'pending' ||
              (retryConflicts && entry.record['syncState'] == 'conflict')));
      final adminApi = AdminApiService(api);
      if (candidates.isEmpty) await api.get('/health');
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
      online = true;
      lastSync = DateTime.now();
      await store.writeJson(File('${store.rootPath}/.meta/sync.json'), {
        'lastSync': lastSync!.toUtc().toIso8601String(),
      });
    } catch (failure) {
      online = failure is ApiNetworkException || failure is ApiTimeoutException
          ? false
          : null;
      error = failure.toString();
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
        conflicts = owned
            .where((entry) => entry.record['syncState'] == 'conflict')
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
    if (acknowledged > 0 && !_disposed && onSynced != null) await onSynced!();
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
    super.dispose();
  }
}
