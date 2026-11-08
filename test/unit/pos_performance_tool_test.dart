import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/services/local_pos_database.dart';

import '../../tool/pos_performance_support.dart';

void main() {
  Future<void> removeRoot(Directory directory) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await directory.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
  test('stock expectations match fixtures for empty, small and large workloads',
      () {
    for (final count in [0, 1, 29, 2000, 3000, 100000]) {
      final fixtures =
          PerformanceFixtures(label: 'audit-$count', billCount: count);
      final deductions = List.filled(PerformanceFixtures.catalogueSize, 0);
      for (var index = 0; index < count; index++) {
        deductions[fixtures.productIndexForBill(index)]++;
      }
      for (var index = 0; index < deductions.length; index++) {
        expect(fixtures.expectedStock(index),
            PerformanceFixtures.initialStock - deductions[index]);
      }
    }
  });

  test('rejects path traversal and unreasonable fixture counts before I/O', () {
    for (final label in [
      '',
      '../bill',
      r'..\bill',
      '/tmp/report',
      'a/b',
      'a.json'
    ]) {
      expect(() => PerformanceFixtures(label: label, billCount: 0),
          throwsArgumentError);
    }
    for (final count in [-1, 100001]) {
      expect(() => PerformanceFixtures(label: 'audit', billCount: count),
          throwsArgumentError);
    }
  });

  test('fixture sale rejects missing products without committing a bill',
      () async {
    final root = await Directory.systemTemp.createTemp('faststore-tool-test-');
    addTearDown(() async {
      await LocalPosDatabase.atPath(
              '${root.path}/offline_pos/faststore_pos.sqlite')
          .close();
      await removeRoot(root);
    });
    final billing = LocalBillingStore(rootPath: '${root.path}/bills');
    final store = OfflinePosStore(
        storageDirectory: root, billingStore: billing, useLocalStock: true);
    await store.saveCatalog([]);
    await expectLater(
        savePerformanceSale(
            billing: billing,
            store: store,
            requestId: '550e8400-e29b-41d4-a716-000000000000',
            productId: 'missing'),
        throwsStateError);
    expect(await billing.records(), isEmpty);
  });

  test('concurrent fixture sales validate fresh stock and cannot oversell',
      () async {
    final root = await Directory.systemTemp.createTemp('faststore-tool-test-');
    addTearDown(() async {
      await LocalPosDatabase.atPath(
              '${root.path}/offline_pos/faststore_pos.sqlite')
          .close();
      await removeRoot(root);
    });
    final billing = LocalBillingStore(rootPath: '${root.path}/bills');
    final store = OfflinePosStore(
        storageDirectory: root, billingStore: billing, useLocalStock: true);
    await store.saveCatalog([
      const PosProduct(
          id: 'tea',
          name: 'Tea',
          sku: 'TEA',
        barcode: '8901234567890',
          price: 10.25,
          unitLabel: 'pcs',
          available: 1)
    ]);
    await store.readCatalog(); // Prime the display estimate before the writes.
    Future<bool> attempt(int index) async {
      try {
        await savePerformanceSale(
            billing: billing,
            store: store,
            requestId:
                '550e8400-e29b-41d4-a716-${index.toString().padLeft(12, '0')}',
            productId: 'tea');
        return true;
      } on StateError {
        return false;
      }
    }

    final outcomes = await Future.wait([attempt(0), attempt(1)]);
    expect(outcomes.where((success) => success), hasLength(1));
    expect(await billing.records(), hasLength(1));
    expect((await store.readCatalog(freshStock: true)).single.available, 0);
    // Retrying the committed request is idempotent, even after stock is exhausted.
    expect(await attempt(0), isTrue);
    expect(await billing.records(), hasLength(1));
  });
}
