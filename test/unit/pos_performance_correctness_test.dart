import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

class _SearchApi extends ApiService {
  int calls = 0;
  final gates = <Completer<dynamic>>[];
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) {
    calls++;
    final gate = Completer<dynamic>();
    gates.add(gate);
    return gate.future;
  }
}

void main() {
  late Directory root;
  late LocalBillingStore bills;
  late OfflinePosStore store;
  const product = PosProduct(
      id: 'tea',
      name: 'Tea',
      sku: 'TEA',
      barcode: '8901234567890',
      price: 10,
      unitLabel: 'pcs',
      available: 100);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('faststore-performance-test-');
    bills = LocalBillingStore(rootPath: '${root.path}/bills');
    store = OfflinePosStore(
        storageDirectory: root, billingStore: bills, useLocalStock: true);
    await store.saveCatalog([product]);
  });
  tearDown(() async => root.delete(recursive: true));

  test('unchanged merges do not rewrite the catalogue or recovery copy',
      () async {
    final file = File('${root.path}/offline_pos/catalog.json');
    final before = await file.stat();
    await store.mergeCatalog([product]);
    expect((await file.stat()).modified, before.modified);
    expect(await File('${file.path}.bak').exists(), isFalse);
    expect((await store.searchCatalog('8901234567890')).single.id, 'tea');
  });

  test('cache invalidates after price and stock changes across store instances',
      () async {
    await store.readCatalog();
    final other = OfflinePosStore(
        storageDirectory: root, billingStore: bills, useLocalStock: true);
    await other.mergeCatalog([
      const PosProduct(
          id: 'tea',
          name: 'Tea',
          sku: 'TEA',
          barcode: '8901234567890',
          price: 20,
          unitLabel: 'pcs',
          available: 99)
    ]);
    final found = (await store.searchCatalog('TEA')).single;
    expect(found.price, 20);
    expect(found.available, 99);
  });

  test('display cache never hides a committed local sale', () async {
    expect((await store.readCatalog()).single.available, 100);
    await bills.saveBill(
        record: {
          'date': '2026-11-03T06:00:00Z',
          'total': 20,
          'items': [
            {'productId': 'tea', 'quantity': 2}
          ],
        },
        requestId: '550e8400-e29b-41d4-a716-446655440000',
        ownerId: 'fixture',
        queueForSync: false,
        uploadPayload: {});
    expect((await store.readCatalog()).single.available, 98);
  });

  test(
      'financial stock validation bypasses estimates and observes external writes',
      () async {
    await store.readCatalog();
    await Directory(bills.rootPath).create(recursive: true);
    await File('${bills.rootPath}/external.json').writeAsString(
        '{"invoiceNumber":"EXTERNAL","trackLocalStock":true,"syncState":"local_only",'
        '"items":[{"productId":"tea","quantity":7}]}',
        flush: true);
    // A separate counter/external writer can change disk during the display TTL.
    expect((await store.readCatalog(freshStock: true)).single.available, 93);
  });

  test(
      'full catalogue refreshes share work, expire on invalidation and retry failures',
      () async {
    var calls = 0;
    final gate = Completer<List<PosProduct>>();
    final a = store.refreshCatalogIfNeeded(() {
      calls++;
      return gate.future;
    });
    final b = store.refreshCatalogIfNeeded(() {
      calls++;
      return gate.future;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete([product]);
    await Future.wait([a, b]);
    expect(calls, 1);
    expect(
        await store.refreshCatalogIfNeeded(() async {
          calls++;
          return [product];
        }),
        isFalse);
    expect(calls, 1);
    OfflinePosStore.invalidateFullRefresh();
    await expectLater(
        store.refreshCatalogIfNeeded(() async => throw StateError('offline')),
        throwsStateError);
    expect(await store.refreshCatalogIfNeeded(() async => [product]), isTrue);
  });

  test(
      'searches deduplicate only in flight and never share across auth changes',
      () async {
    final api = _SearchApi();
    final admin = AdminApiService(api);
    final first = admin.searchPosProducts('TEA');
    final duplicate = admin.searchPosProducts(' TEA ');
    expect(api.calls, 1);
    api.setAuthToken('different-test-session');
    final otherUser = admin.searchPosProducts('TEA');
    expect(api.calls, 2);
    for (final gate in api.gates) {
      gate.complete({'products': []});
    }
    await Future.wait([first, duplicate, otherUser]);
    final refresh = admin.searchPosProducts('TEA');
    expect(api.calls, 3);
    api.gates.last.complete({'products': []});
    await refresh;
  });
}
