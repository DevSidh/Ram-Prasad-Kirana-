import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/local_billing_sync.dart';

void main() {
  late Directory sandbox;
  late LocalBillingStore store;
  const key = '550e8400-e29b-41d4-a716-446655440000';
  Future<void> seed({bool queued = true, String owner = 'admin-test'}) async {
    await store.saveBill(
        requestId: key,
        ownerId: owner,
        queueForSync: queued,
        uploadPayload: {
          'idempotencyKey': key
        },
        record: {
          'date': '2020-01-02T06:00:00.000Z',
          'total': 20,
          'items': [
            {'productId': 'tea', 'sku': 'TEST-TEA', 'quantity': 2}
          ],
        });
  }

  Map<String, dynamic> responseSale() => {
        'id': 'server-sale-test',
        'receiptNumber': 'POS-${key.toUpperCase()}',
        'invoiceNumber': store.invoiceNumber(key, DateTime.utc(2020, 1, 2)),
        'createdAt': '2020-01-02T06:00:00.000Z',
        'total': 20,
        'items': [],
        'paymentStatus': 'COMPLETED',
        'status': 'COMPLETED',
      };
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('faststore-sync-test-');
    store = LocalBillingStore(rootPath: '${sandbox.path}/bills');
  });
  tearDown(() async {
    expect(sandbox.path, startsWith(Directory.systemTemp.path));
    await sandbox.delete(recursive: true);
  });

  test(
      'lost acknowledgement survives restart and reuses the same request reference',
      () async {
    await seed();
    var requests = 0;
    var centralCommits = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 200);
      final payload = jsonDecode(request.body) as Map;
      expect(payload['idempotencyKey'], key);
      requests++;
      if (centralCommits == 0) centralCommits++;
      if (requests == 1) {
        throw http.ClientException('Connection lost after commit');
      }
      return http.Response(jsonEncode({'sale': responseSale()}), 200);
    });
    final api =
        ApiService(baseUrl: 'https://billing.invalid/api/v1', client: client);
    var sync = LocalBillingSync(
        api: api,
        ownerId: 'admin-test',
        store: store,
        refreshStock: (_) async {});
    await sync.synchronize();
    expect(sync.pending, 1);
    expect(sync.online, false);
    sync.dispose();
    sync = LocalBillingSync(
        api: api,
        ownerId: 'admin-test',
        store: store,
        refreshStock: (_) async {});
    await sync.synchronize();
    expect(sync.pending, 0);
    expect(centralCommits, 1);
    expect(requests, 2);
    expect((await store.records()).single.record['serverSaleId'],
        'server-sale-test');
    sync.dispose();
    client.close();
  });

  test('price/stock conflicts stay visible and require explicit reviewed retry',
      () async {
    await seed();
    var posts = 0;
    var conflict = true;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 200);
      posts++;
      return conflict
          ? http.Response('{"error":"Stock conflict"}', 409)
          : http.Response(jsonEncode({'sale': responseSale()}), 201);
    });
    final sync = LocalBillingSync(
        api: ApiService(baseUrl: 'https://billing.invalid', client: client),
        ownerId: 'admin-test',
        store: store,
        refreshStock: (_) async {});
    await sync.synchronize();
    expect(sync.conflicts, hasLength(1));
    expect((await store.records()).single.record['total'], 20);
    await sync.synchronize();
    expect(posts, 1);
    conflict = false;
    await sync.synchronize(retryConflicts: true);
    expect(posts, 2);
    expect(sync.conflicts, isEmpty);
    sync.dispose();
    client.close();
  });

  test('computer-only and another account records are never uploaded',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response('{}', 200);
    });
    await seed(owner: 'other-admin');
    var sync = LocalBillingSync(
        api: ApiService(baseUrl: 'https://billing.invalid', client: client),
        ownerId: 'admin-test',
        store: store);
    await sync.synchronize();
    expect(sync.pending, 0);
    expect((await store.records()).single.record['syncState'], 'pending');
    sync.dispose();
    final secondRoot =
        LocalBillingStore(rootPath: '${sandbox.path}/local-only');
    await secondRoot.saveBill(
        requestId: key,
        ownerId: 'admin-test',
        queueForSync: false,
        uploadPayload: {},
        record: {'date': '2020-01-02T06:00:00Z', 'total': 20, 'items': []});
    sync = LocalBillingSync(
        api: ApiService(baseUrl: 'https://billing.invalid', client: client),
        ownerId: 'admin-test',
        store: secondRoot);
    await sync.synchronize();
    expect(sync.localOnly, 1);
    sync.dispose();
    client.close();
  });
}
