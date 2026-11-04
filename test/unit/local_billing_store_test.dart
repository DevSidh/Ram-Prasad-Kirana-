import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';

void main() {
  late Directory sandbox;
  late LocalBillingStore store;
  const key = '550e8400-e29b-41d4-a716-446655440000';
  Map<String, dynamic> bill() => {
        'date': '2026-11-03T06:00:00.000Z',
        'customerName': 'Test customer',
        'customerPhone': '9800000000',
        'total': 20.0,
        'paidAmount': 10.0,
        'outstandingAmount': 10.0,
        'paymentStatus': 'PENDING',
        'paymentMethod': 'PENDING',
        'status': 'COMPLETED',
        'items': [
          {
            'productId': 'test-tea',
            'sku': 'TEST-TEA',
            'name': 'Tea',
            'quantity': 2,
            'weightGrams': null,
            'unitPrice': 10.0,
            'amount': 20.0
          }
        ],
      };
  Future<File> save({bool queued = false, String requestId = key}) =>
      store.saveBill(
        record: bill(),
        requestId: requestId,
        ownerId: 'test-admin',
        queueForSync: queued,
        uploadPayload: {'idempotencyKey': requestId},
      );

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('faststore-local-test-');
    store = LocalBillingStore(rootPath: '${sandbox.path}/bills');
  });
  tearDown(() async {
    expect(
        sandbox.absolute.path, startsWith(Directory.systemTemp.absolute.path));
    await sandbox.delete(recursive: true);
  });

  test(
      'committed bills survive restart and an identical retry never duplicates stock',
      () async {
    await save(queued: true);
    await save(queued: true);
    final restarted = LocalBillingStore(rootPath: store.rootPath);
    final entries = await restarted.records();
    expect(entries, hasLength(1));
    expect(entries.single.record['syncState'], 'pending');
    expect(await restarted.stockDeductions(), {'test-tea': 2});
    expect(entries.single.record['total'], 20.0);
    await restarted.setSyncResult(entries.single.file,
        state: 'synced',
        serverSale: {
          'id': 'test-sale',
          'invoiceNumber': entries.single.record['invoiceNumber']
        });
    expect(await restarted.stockDeductions(), isEmpty);
  });

  test('distinct counters and parallel writes keep distinct references',
      () async {
    await Future.wait([
      save(),
      save(requestId: '550e8400-e29b-41d4-a716-446655440001'),
    ]);
    final entries = await store.records();
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.record['invoiceNumber']).toSet(),
        hasLength(2));
    expect(await store.stockDeductions(), {'test-tea': 4});
  });

  test(
      'same reference with different contents cannot overwrite a financial record',
      () async {
    final original = await save();
    await expectLater(
        store.saveBill(
            record: {...bill(), 'total': 21.0},
            requestId: key,
            ownerId: 'test-admin',
            queueForSync: false,
            uploadPayload: {}),
        throwsStateError);
    expect((await store.readJson(original))['total'], 20.0);
  });

  test('interrupted replacement recovers the prior committed copy', () async {
    final file = await save();
    final original = await store.readJson(file);
    await store.updateLocalBill(
        file, {...original, 'paidAmount': 15.0, 'outstandingAmount': 5.0});
    await file.writeAsString('{interrupted');
    expect((await store.readJson(file))['paidAmount'], 10.0);
    expect((await store.readJson(file))['_recoveredFromBackup'], isTrue);
    await expectLater(store.updateLocalBill(file, original), throwsStateError);
  });

  test(
      'queued bills cannot be locally changed while server acknowledgement is unknown',
      () async {
    final file = await save(queued: true);
    await expectLater(
        store.updateLocalBill(
            file, {...await store.readJson(file), 'paidAmount': 20.0}),
        throwsStateError);
  });

  test(
      'backup restores exact records and customer CSV to an isolated new folder',
      () async {
    final file = await save();
    final customer = File('${store.rootPath}/bill customer/test.csv');
    await customer.parent.create(recursive: true);
    await customer.writeAsString('"Customer","9800000000"\r\n');
    final backup =
        await store.createBackup(File('${sandbox.path}/backup.fsbak'));
    final restored = await store.restoreBackup(
        backup, Directory('${sandbox.path}/restored'));
    expect(
        await File('${restored.path}/${file.uri.pathSegments.last}')
            .readAsString(),
        await file.readAsString());
    expect(await File('${restored.path}/bill customer/test.csv').readAsString(),
        await customer.readAsString());
    await expectLater(store.restoreBackup(backup, Directory(store.rootPath)),
        throwsStateError);
  });

  test(
      'restore rejects corrupted digests and path traversal before writing files',
      () async {
    final archive = File('${sandbox.path}/invalid.fsbak');
    for (final entry in [
      {
        'path': '../escape.txt',
        'data': base64Encode([1]),
        'sha256': 'bad'
      },
      {
        'path': 'bill.json',
        'data': base64Encode([1]),
        'sha256': 'bad'
      },
    ]) {
      await archive.writeAsBytes(gzip.encode(utf8.encode(jsonEncode({
        'format': 'faststore-local-backup',
        'version': 1,
        'entries': [entry],
      }))));
      final output = Directory('${sandbox.path}/rejected');
      await expectLater(
          store.restoreBackup(archive, output), throwsFormatException);
      expect(await output.exists(), isFalse);
    }
    expect(await File('${sandbox.path}/escape.txt').exists(), isFalse);
  });

  PosProduct product(String id, int stock) => PosProduct(
        id: id,
        name: id,
        sku: id,
        barcode: null,
        price: 10,
        unitLabel: '1 pc',
        available: stock,
      );

  test('catalogue refresh never persists already-deducted local stock twice',
      () async {
    final catalog = OfflinePosStore(
        storageDirectory: sandbox, billingStore: store, useLocalStock: true);
    await catalog.saveCatalog([product('test-tea', 10)]);
    final file = await save(queued: true);
    expect((await catalog.readCatalog()).single.available, 8);
    await catalog.mergeCatalog([product('test-tea', 10)]);
    expect((await catalog.readCatalog()).single.available, 8);
    await catalog.mergeCatalog([product('test-tea', 8)]);
    await store
        .setSyncResult(file, state: 'synced', serverSale: {'id': 'test-sale'});
    expect((await catalog.readCatalog()).single.available, 8);
  });

  test('a stale payment snapshot cannot overwrite a newer collected balance',
      () async {
    final file = await save();
    final original = await store.readJson(file);
    await store.updateLocalBill(
        file, {...original, 'paidAmount': 15.0, 'outstandingAmount': 5.0},
        expectedPaidAmount: 10.0);
    await expectLater(
        store.updateLocalBill(
            file, {...original, 'paidAmount': 20.0, 'outstandingAmount': 0.0},
            expectedPaidAmount: 10.0),
        throwsStateError);
    expect((await store.readJson(file))['paidAmount'], 15.0);
  });

  test('parallel catalogue merges preserve all independently fetched products',
      () async {
    final catalog = OfflinePosStore(
        storageDirectory: sandbox, billingStore: store, useLocalStock: true);
    await Future.wait([
      catalog.mergeCatalog([product('tea-a', 5)]),
      catalog.mergeCatalog([product('tea-b', 6)]),
    ]);
    expect((await catalog.readCatalog()).map((item) => item.id).toSet(),
        {'tea-a', 'tea-b'});
  });

  test('a damaged catalogue recovers its previous complete snapshot', () async {
    final catalog = OfflinePosStore(
        storageDirectory: sandbox, billingStore: store, useLocalStock: true);
    await catalog.saveCatalog([product('test-tea', 10)]);
    await catalog.mergeCatalog([product('test-tea', 20)]);
    await File('${sandbox.path}/offline_pos/catalog.json')
        .writeAsString('{interrupted');
    expect((await catalog.readCatalog()).single.available, 10);
  });
}
