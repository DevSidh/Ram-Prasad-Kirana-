import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'inventory_changes.dart';
import 'local_pos_database.dart';

/// Durable financial snapshots. An explicit computer-only bill is never queued.
/// The directory override is used by isolated persistence/restore tests.
class LocalBillingStore {
  const LocalBillingStore({this.rootPath = 'C:/Ramprasad store/bills'});

  final String rootPath;
  static final Map<String, Future<void>> _writers = {};
  static const _uuid = Uuid();
  static final _displayStock =
      <String, ({DateTime time, Map<String, int> values})>{};
  static final _displayLoads = <String, Future<Map<String, int>>>{};
  static int _displayRevision = 0;
  static final _priceDisplay =
      <String, ({int revision, Map<String, double> prices})>{};
  Future<Map<String, double>> pendingCataloguePrices() async {
    final key = Directory(rootPath).absolute.path;
    final cached = _priceDisplay[key];
    if (cached?.revision == _displayRevision) return cached!.prices;
    final revision = _displayRevision;
    final entries = await records();
    entries
        .sort((a, b) => '${a.record['date']}'.compareTo('${b.record['date']}'));
    final prices = <String, double>{};
    for (final entry in entries) {
      if ((entry.record['postCommit'] as Map?)?['prices'] == true) continue;
      for (final change
          in (entry.record['cataloguePriceChanges'] as List? ?? [])
              .whereType<Map>()) {
        prices[change['productId'] as String] =
            (change['price'] as num).toDouble();
      }
    }
    _priceDisplay[key] = (revision: revision, prices: prices);
    return prices;
  }

  /// One-second display estimate only. Financial validation always calls
  /// stockDeductions() directly under the existing writer lock.
  Future<Map<String, int>> stockDeductionsForDisplay() async {
    final key = Directory(rootPath).absolute.path;
    final cached = _displayStock[key];
    if (cached != null &&
        DateTime.now().difference(cached.time) < const Duration(seconds: 1)) {
      return cached.values;
    }
    final existing = _displayLoads[key];
    if (existing != null) return existing;
    final revision = _displayRevision;
    final future = stockDeductions();
    _displayLoads[key] = future;
    try {
      final values = Map<String, int>.unmodifiable(await future);
      if (revision == _displayRevision) {
        if (_displayStock.length >= 8) {
          _displayStock.remove(_displayStock.keys.first);
        }
        _displayStock[key] = (time: DateTime.now(), values: values);
      }
      return values;
    } finally {
      if (identical(_displayLoads[key], future)) _displayLoads.remove(key);
    }
  }

  Future<T> withLock<T>(Future<T> Function() work) => _locked(work);

  /// A saved manual payment is printed automatically at most once. Reprints
  /// remain explicit actions on the same committed bill.
  Future<bool> claimInitialPrint(File file) => _locked(() async {
        final record = await readJson(file);
        if (record['initialPrintClaimedAt'] != null) return false;
        await writeJson(file, {
          ...record,
          'initialPrintClaimedAt': DateTime.now().toUtc().toIso8601String()
        });
        return true;
      });

  String invoiceNumber(String requestId, DateTime date) {
    if (!RegExp(r'^[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')
        .hasMatch(requestId)) {
      throw const FormatException('Invalid bill request reference.');
    }
    // Full UUID: independent devices/counters never share a local sequence.
    final nepalDate = date.toUtc().add(const Duration(hours: 5, minutes: 45));
    return 'RPGS-INV-${nepalDate.year}-L-${requestId.replaceAll('-', '').toUpperCase()}';
  }

  Future<T> _locked<T>(Future<T> Function() work) async {
    final root = Directory(rootPath).absolute;
    final previous = _writers[root.path] ?? Future<void>.value();
    final done = Completer<void>();
    _writers[root.path] = done.future;
    await previous;
    RandomAccessFile? handle;
    try {
      await root.create(recursive: true);
      handle =
          await File('${root.path}/.writer.lock').open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      return await work();
    } finally {
      try {
        if (handle != null) {
          try {
            await handle.unlock();
          } finally {
            await handle.close();
          }
        }
      } finally {
        done.complete();
      }
    }
  }

  Future<void> writeJson(File file, Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${_uuid.v4()}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) {
      try {
        jsonDecode(await file.readAsString());
        await file.copy('${file.path}.bak');
      } on FormatException {
        // Preserve the good recovery copy when the primary is damaged.
      }
    }
    // Do not delete the old committed file before replacing it.
    await temp.rename(file.path);
    // Includes sale, collection and sync changes from every store instance.
    _displayRevision++;
    InventoryChanges.notify();
    _displayStock.clear();
    _displayLoads.clear();
  }

  Future<Map<String, dynamic>> readJson(File file) async {
    Object? primaryError;
    for (final candidate in [file, File('${file.path}.bak')]) {
      try {
        final value = jsonDecode(await candidate.readAsString());
        if (value is Map<String, dynamic>) {
          return {
            ...value,
            if (candidate.path != file.path) '_recoveredFromBackup': true,
          };
        }
        throw const FormatException('Invalid bill record.');
      } catch (error) {
        primaryError ??= error;
      }
    }
    throw FileSystemException(
        'Cannot read bill or recovery copy: $primaryError', file.path);
  }

  Future<File> saveBill({
    required Map<String, dynamic> record,
    required String requestId,
    required String ownerId,
    required bool queueForSync,
    required Map<String, dynamic> uploadPayload,
    Future<void> Function()? validate,
  }) =>
      _locked(() async {
        final date = DateTime.parse(record['date'] as String);
        final reference = invoiceNumber(requestId, date);
        final file = File('$rootPath/$reference.json');
        if (await file.exists()) {
          final previous = await readJson(file);
          if (previous['idempotencyKey'] != requestId ||
              previous['total'] != record['total'] ||
              jsonEncode(previous['roomPicks']) !=
                  jsonEncode(record['roomPicks']) ||
              jsonEncode(previous['items']) != jsonEncode(record['items'])) {
            throw StateError(
                'This bill reference is already committed with different contents.');
          }
          return file;
        }
        if (queueForSync && ownerId.isEmpty) {
          throw StateError(
              'Sign in before creating a bill for server synchronization.');
        }
        if (validate != null) await validate();
        await writeJson(file, {
          ...record,
          'invoiceNumber': reference,
          'recordVersion': 1,
          'idempotencyKey': requestId,
          'ownerId': ownerId,
          'trackLocalStock': true,
          'syncState': queueForSync ? 'pending' : 'local_only',
          'syncError': null,
          if (queueForSync) 'uploadPayload': uploadPayload,
        });
        if (Platform.isWindows &&
            rootPath.replaceAll('\\', '/').toLowerCase() ==
                'c:/ramprasad store/bills') {
          try {
            final database = await LocalPosDatabase.defaultInstance();
            final localRecord = {
              ...record,
              'id': record['id'] ?? reference,
              'invoiceNumber': reference,
              'syncState': queueForSync ? 'pending' : 'local_only',
            };
            await database.saveBill(localRecord);
            if (queueForSync) {
              await database.enqueue(
                id: requestId,
                entityType: 'bill',
                entityId: reference,
                operation: 'create',
                payload: uploadPayload,
              );
            }
          } catch (_) {
            // The durable JSON bill and retry queue remain the recovery source.
          }
        }
        return file;
      });

  Future<List<({File file, Map<String, dynamic> record})>> records() async {
    final directory = Directory(rootPath);
    if (!await directory.exists()) return [];
    final result = <({File file, Map<String, dynamic> record})>[];
    final batch = <File>[];
    Future<void> readBatch() async {
      // Bounded asynchronous reads reduce per-file waiting for long histories.
      // No cached financial values: every primary/recovery file is read afresh.
      final values = await Future.wait(batch
          .map((file) async => (file: file, record: await readJson(file))));
      for (final entry in values) {
        if (entry.record['invoiceNumber'] is String &&
            entry.record['items'] is List) {
          result.add(entry);
        }
      }
      batch.clear();
    }

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      batch.add(entity);
      if (batch.length == 8) await readBatch();
    }
    if (batch.isNotEmpty) await readBatch();
    return result;
  }

  Future<void> setSyncResult(
    File file, {
    required String state,
    String? error,
    Map<String, dynamic>? serverSale,
  }) =>
      _locked(() async {
        final record = await readJson(file);
        await writeJson(file, {
          ...record,
          'syncState': state,
          'syncError': error,
          if (serverSale != null) ...{
            'serverSaleId': serverSale['id'],
            'serverInvoiceNumber': serverSale['invoiceNumber'],
            'serverReceiptNumber': serverSale['receiptNumber'],
            'syncedAt': DateTime.now().toUtc().toIso8601String(),
          },
        });
        if (Platform.isWindows &&
            rootPath.replaceAll('\\', '/').toLowerCase() ==
                'c:/ramprasad store/bills') {
          try {
            final database = await LocalPosDatabase.defaultInstance();
            await database.updateBillSyncState(
                record['id']?.toString() ??
                    record['invoiceNumber']?.toString() ??
                    '',
                state);
            final requestId = record['idempotencyKey']?.toString();
            if (requestId != null && requestId.isNotEmpty) {
              if (state == 'synced') {
                await database.completeOutbox(requestId);
              } else if (error != null) {
                await database.recordOutboxFailure(requestId, error);
              }
            }
          } catch (_) {
            // The JSON record remains authoritative if SQLite is unavailable.
          }
        }
      });

  Future<void> updateLocalBill(File file, Map<String, dynamic> record,
          {double? expectedPaidAmount}) =>
      _locked(() async {
        final current = await readJson(file);
        if (current['_recoveredFromBackup'] == true) {
          throw StateError(
              'This record was recovered from a previous copy. Review its payment history before changing the balance.');
        }
        if (expectedPaidAmount != null &&
            double.tryParse('${current['paidAmount'] ?? 0}') !=
                expectedPaidAmount) {
          throw StateError(
              'This local balance changed. Refresh the bill before recording payment.');
        }
        if (current['syncState'] == 'pending' ||
            current['syncState'] == 'conflict' ||
            current['syncState'] == 'synced') {
          throw StateError(
              'Synchronize this queued bill before collecting another payment.');
        }
        await writeJson(file, {
          ...record,
          if (current['postCommit'] is Map) ...{
            'postCommit': {
              ...Map<String, dynamic>.from(current['postCommit'] as Map),
              'archive': false,
              'pendingCash': false
            },
            'receiptSnapshot': {
              ...Map<String, dynamic>.from(current['receiptSnapshot'] as Map),
              'paymentStatus': record['paymentStatus'],
              'paymentMethod': record['paymentMethod'],
              'paidAmount': record['paidAmount'],
              'outstandingAmount': record['outstandingAmount'],
              'paymentCollections': record['paymentCollections'] ?? [],
            },
          }
        });
      });

  Future<Map<String, int>> stockDeductions() async {
    final result = <String, int>{};
    for (final entry in await records()) {
      if (entry.record['trackLocalStock'] != true ||
          entry.record['syncState'] == 'synced' ||
          entry.record['roomStockSyncedAt'] != null ||
          entry.record['status'] == 'CANCELLED') {
        continue;
      }
      for (final item in (entry.record['items'] as List).whereType<Map>()) {
        final id = item['productId']?.toString();
        final quantity = item['weightGrams'] ?? item['quantity'];
        if (id != null && !id.startsWith('manual-') && quantity is num) {
          result[id] = (result[id] ?? 0) + quantity.toInt();
        }
      }
    }
    return result;
  }

  Future<void> setRoomStockSyncResult(File file,
          {String? error, bool synced = false}) =>
      _locked(() async {
        final record = await readJson(file);
        await writeJson(file, {
          ...record,
          'roomStockSyncError': error,
          'roomStockSyncState': synced ? 'synced' : 'conflict',
          if (synced)
            'roomStockSyncedAt': DateTime.now().toUtc().toIso8601String()
        });
      });

  /// Full local-record export, excluding lock/temp/recovery files. Never tokens.
  Future<File> createBackup(File target) => _locked(() async {
        final root = Directory(rootPath).absolute;
        final targetPath = Platform.isWindows
            ? target.absolute.path.toLowerCase()
            : target.absolute.path;
        final rootPrefix = '${root.path}${Platform.pathSeparator}';
        if (targetPath.startsWith(
            Platform.isWindows ? rootPrefix.toLowerCase() : rootPrefix)) {
          throw StateError(
              'Choose a backup location outside the bills folder.');
        }
        final entries = <Map<String, dynamic>>[];
        var byteCount = 0;
        await for (final entity
            in root.list(recursive: true, followLinks: false)) {
          if (entity is! File ||
              entity.path.endsWith('.tmp') ||
              entity.path.endsWith('.bak') ||
              entity.path.endsWith('.lock')) {
            continue;
          }
          final bytes = await entity.readAsBytes();
          byteCount += bytes.length;
          if (byteCount > 128 * 1024 * 1024 || entries.length >= 10000) {
            throw StateError(
                'This local backup exceeds the 128 MB limit. Archive older records separately.');
          }
          entries.add({
            'path': entity.absolute.path
                .substring(root.path.length + 1)
                .replaceAll('\\', '/'),
            'sha256': sha256.convert(bytes).toString(),
            'data': base64Encode(bytes),
          });
        }
        final bytes = gzip.encode(utf8.encode(jsonEncode({
          'format': 'faststore-local-backup',
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'entries': entries,
        })));
        await target.parent.create(recursive: true);
        final temporary = File('${target.path}.tmp');
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(target.path);
        return target;
      });

  /// Restores only to a NEW directory after validating every path and digest.
  /// Live files are never overwritten or merged by restore.
  Future<Directory> restoreBackup(File source, Directory destination) async {
    if (await destination.exists()) {
      throw StateError('Restore requires a new, empty destination.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source.openRead().transform(gzip.decoder)) {
      builder.add(chunk);
      if (builder.length > 200 * 1024 * 1024) {
        throw const FormatException('Backup exceeds the restore limit.');
      }
    }
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map ||
        decoded['format'] != 'faststore-local-backup' ||
        decoded['version'] != 1 ||
        decoded['entries'] is! List ||
        (decoded['entries'] as List).length > 10000) {
      throw const FormatException('Unsupported local backup.');
    }
    final validated = <String, List<int>>{};
    for (final entry in decoded['entries'] as List) {
      if (entry is! Map ||
          entry['path'] is! String ||
          entry['data'] is! String) {
        throw const FormatException('Invalid backup entry.');
      }
      final path = entry['path'] as String;
      if (path.isEmpty ||
          path.contains('\\') ||
          path.contains(':') ||
          path
              .split('/')
              .any((part) => part.isEmpty || part == '..' || part == '.')) {
        throw const FormatException('Unsafe backup path.');
      }
      final bytes = base64Decode(entry['data'] as String);
      if (sha256.convert(bytes).toString() != entry['sha256'] ||
          validated.containsKey(path)) {
        throw const FormatException('Backup integrity verification failed.');
      }
      validated[path] = bytes;
    }
    final temporary = Directory('${destination.path}.restore-${_uuid.v4()}');
    await temporary.create(recursive: true);
    for (final entry in validated.entries) {
      final file = File('${temporary.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    return temporary.rename(destination.path);
  }
}
