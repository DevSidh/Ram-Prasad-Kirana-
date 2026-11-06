import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/local_billing_sync.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

class _StockApi extends ApiService {
  final keys = <String>{};
  int physicalDeductions = 0, requests = 0;
  bool conflict = false;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    if (endpoint == '/health') return {};
    throw StateError('Unexpected fixture read $endpoint');
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/admin/billing/rooms/local-sales') {
      requests++;
      expect(body.keys.toSet(), {'requestId', 'items', 'roomPicks'});
      expect(body.toString(), isNot(contains('PRIVATE CUSTOMER')));
      if (conflict) {
        throw const ApiResponseException('Selected room is out of stock.',
            statusCode: 409);
      }
      if (keys.add(body['requestId'] as String)) physicalDeductions++;
      return {
        'success': true,
        'requestId': body['requestId'],
        'productIds': {'tea': 'tea'}
      };
    }
    if (endpoint == '/admin/billing/rooms/availability') {
      return {
        'rooms': [
          {'id': 'a', 'name': 'Main store', 'number': '01', 'active': true}
        ],
        'stocks': [
          {'roomId': 'a', 'productId': 'tea', 'quantity': 7}
        ],
        'totals': [
          {'productId': 'tea', 'total': 7, 'available': 7}
        ],
        'products': [],
        'capturedAt': '2026-11-06T00:00:00Z',
      };
    }
    throw StateError('Unexpected fixture write $endpoint');
  }
}

void main() {
  late Directory root;
  late LocalBillingStore store;
  late _StockApi api;
  late File file;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('faststore-room-sync-');
    store = LocalBillingStore(rootPath: '${root.path}/bills');
    api = _StockApi();
    file = await store.saveBill(
        requestId: '11111111-1111-4111-8111-111111111111',
        ownerId: 'fixture',
        queueForSync: false,
        uploadPayload: {},
        record: {
          'date': '2026-11-06T00:00:00Z',
          'status': 'COMPLETED',
          'total': 30,
          'customerName': 'PRIVATE CUSTOMER',
          'items': [
            {'productId': 'tea', 'sku': 'TEA', 'quantity': 3}
          ],
          'roomPicks': [
            {'productId': 'tea', 'roomId': 'a', 'quantity': 3}
          ],
        });
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  LocalBillingSync synchronizer(
          Future<void> Function(Map<String, dynamic>) refresh) =>
      LocalBillingSync(
          api: api,
          ownerId: 'fixture',
          store: store,
          catalogStore: OfflinePosStore(
              storageDirectory: root, billingStore: store, useLocalStock: true),
          refreshStock: refresh);

  test(
      'computer-only bill shares stock only and clears projection after acknowledgement',
      () async {
    final sync = synchronizer((_) async {});
    addTearDown(sync.dispose);
    expect(await store.stockDeductions(), {'tea': 3});
    await sync.synchronize();
    await sync.synchronize();
    expect(api.physicalDeductions, 1);
    expect(api.requests, 1);
    expect(await store.stockDeductions(), isEmpty);
    final record = await store.readJson(file);
    expect(record['syncState'], 'local_only');
    expect(record['customerName'], 'PRIVATE CUSTOMER');
    expect(record['roomStockSyncedAt'], isNotNull);
    expect(sync.stockPending, 0);
  });
  test(
      'uncertain stock refresh retains request and retry does not consume twice',
      () async {
    var attempts = 0;
    final sync = synchronizer((_) async {
      if (++attempts == 1) throw const ApiNetworkException();
    });
    addTearDown(sync.dispose);
    await sync.synchronize();
    expect((await store.readJson(file))['roomStockSyncedAt'], isNull);
    expect(await store.stockDeductions(), {'tea': 3});
    await sync.synchronize();
    expect(api.requests, 2);
    expect(api.physicalDeductions, 1);
    expect(await store.stockDeductions(), isEmpty);
  });
  test('stock conflict preserves the paid local bill and requires review',
      () async {
    api.conflict = true;
    final sync = synchronizer((_) async {});
    addTearDown(sync.dispose);
    await sync.synchronize();
    await sync.synchronize();
    expect(api.requests, 1);
    expect(api.physicalDeductions, 0);
    final record = await store.readJson(file);
    expect(record['status'], 'COMPLETED');
    expect(record['total'], 30);
    expect(record['roomStockSyncState'], 'conflict');
    expect(sync.conflicts, hasLength(1));
    expect(await store.stockDeductions(), {'tea': 3});
  });
}
