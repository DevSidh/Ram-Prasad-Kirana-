import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/room_inventory.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/room_inventory_service.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

Map<String, dynamic> fixture() => {
      'rooms': [
        {'id': 'a', 'name': 'Main store', 'number': '01', 'active': true},
        {'id': 'b', 'name': 'Back room', 'number': '02', 'active': true}
      ],
      'stocks': [
        {'roomId': 'a', 'productId': 'tea', 'quantity': 6},
        {'roomId': 'b', 'productId': 'tea', 'quantity': 2}
      ],
      'totals': [
        {'productId': 'tea', 'total': 10, 'available': 8}
      ],
      'capturedAt': '2026-11-06T00:00:00Z',
    };

class _Bills extends LocalBillingStore {
  _Bills(this.bills);
  final List<Map<String, dynamic>> bills;
  @override
  Future<List<({File file, Map<String, dynamic> record})>> records() async =>
      [for (final bill in bills) (file: File('fixture-only'), record: bill)];
}

void main() {
  test(
      'offline overselling flags the product and keeps room totals non-negative and bounded',
      () async {
    final json = fixture();
    json['totals'] = [
      {'productId': 'tea', 'total': 2, 'available': 2}
    ];
    json['stocks'] = [
      {'productId': 'tea', 'roomId': 'a', 'quantity': 1},
      {'productId': 'tea', 'roomId': 'b', 'quantity': 1}
    ];
    final store = OfflinePosStore(
        useLocalStock: true,
        billingStore: _Bills([
          {
            'trackLocalStock': true,
            'syncState': 'local_only',
            'items': [
              {'productId': 'tea', 'quantity': 3}
            ],
            'roomPicks': [
              {'productId': 'tea', 'roomId': 'a', 'quantity': 3}
            ]
          }
        ]));
    final projected =
        await RoomInventoryService(AdminApiService(ApiService()), store)
            .project(RoomInventorySnapshot.fromJson(json));
    expect(projected.conflictedProducts, contains('tea'));
    expect(projected.totals['tea']!.total, 0);
    expect(projected.quantity('tea', 'a') + projected.quantity('tea', 'b'), 0);
  });
  test('unassigned is a remainder; split picks must equal bill base units', () {
    final snapshot = RoomInventorySnapshot.fromJson(fixture());
    expect(snapshot.quantity('tea', null), 2);
    snapshot.validatePicks(const [
      RoomPick(productId: 'tea', roomId: 'a', quantity: 3),
      RoomPick(productId: 'tea', roomId: 'b', quantity: 2)
    ], {
      'tea': 5
    });
    expect(
        () => snapshot.validatePicks(
            const [RoomPick(productId: 'tea', roomId: 'a', quantity: 7)],
            {'tea': 7}),
        throwsStateError);
    expect(
        () => snapshot.validatePicks(
            const [RoomPick(productId: 'tea', roomId: 'a', quantity: 2)],
            {'tea': 3}),
        throwsStateError);
    expect(
        () => snapshot.validatePicks(const [
              RoomPick(productId: 'tea', roomId: 'a', quantity: 1),
              RoomPick(productId: 'tea', roomId: 'a', quantity: 1)
            ], {
              'tea': 2
            }),
        throwsStateError);
    expect(
        () => snapshot.validatePicks(const [
              RoomPick(productId: 'tea', roomId: 'a', quantity: 6),
              RoomPick(productId: 'tea', roomId: 'b', quantity: 2),
              RoomPick(productId: 'tea', roomId: null, quantity: 1)
            ], {
              'tea': 9
            }),
        throwsStateError);
  });
  test('loose weights use grams, wholesale sacks stay as packs', () {
    PosProduct p(String id, String unit) => PosProduct(
        id: id,
        name: id,
        sku: id,
        barcode: null,
        price: 10,
        unitLabel: unit,
        available: 5000);
    expect(roomStockUnit(p('rice', '1 kg')), 'g');
    expect(roomStockUnit(p('rice', '500 g')), 'g');
    expect(roomStockUnit(p('wholesale-rice', '25 kg sack')), '25 kg sack');
  });
  test(
      'pending retail kilograms normalize to grams while wholesale packs do not',
      () {
    Map<String, dynamic> queued(String kind, String unit) => {
          'kind': kind,
          'stock': 2.5,
          'posProduct': {
            'id': 'offline-1',
            'name': 'Rice',
            'sku': 'RICE',
            'barcode': null,
            'price': 10,
            'unitLabel': unit,
            'available': 3
          }
        };
    expect(
        OfflinePosStore.pendingProductSnapshot(queued('retail', '1 kg'))
            .available,
        2500);
    expect(
        OfflinePosStore.pendingProductSnapshot(queued('wholesale', '25 kg'))
            .available,
        3);
  });
  test(
      'unsynced local sales deduct from the selected room only, once acknowledged they stop projecting',
      () async {
    final bill = <String, dynamic>{
      'trackLocalStock': true,
      'syncState': 'local_only',
      'status': 'COMPLETED',
      'roomPicks': [
        {'productId': 'tea', 'roomId': 'a', 'quantity': 3}
      ],
      'items': [
        {'productId': 'tea', 'quantity': 3}
      ]
    };
    final store =
        OfflinePosStore(billingStore: _Bills([bill]), useLocalStock: true);
    final service = RoomInventoryService(
        AdminApiService(ApiService(baseUrl: 'http://127.0.0.1:1')), store);
    var projected =
        await service.project(RoomInventorySnapshot.fromJson(fixture()));
    expect(projected.quantity('tea', 'a'), 3);
    expect(projected.quantity('tea', 'b'), 2);
    expect(projected.totals['tea']!.total, 7);
    expect(projected.totals['tea']!.available, 5);
    bill['roomStockSyncedAt'] = '2026-11-06T01:00:00Z';
    projected =
        await service.project(RoomInventorySnapshot.fromJson(fixture()));
    expect(projected.quantity('tea', 'a'), 6);
  });
  test(
      'pre-room bills use unassigned first; cancelled and server-synced bills do not deduct',
      () async {
    final store = OfflinePosStore(
        billingStore: _Bills([
          {
            'trackLocalStock': true,
            'syncState': 'local_only',
            'items': [
              {'productId': 'tea', 'quantity': 4}
            ]
          },
          {
            'trackLocalStock': true,
            'syncState': 'synced',
            'items': [
              {'productId': 'tea', 'quantity': 10}
            ]
          },
          {
            'trackLocalStock': true,
            'syncState': 'local_only',
            'status': 'CANCELLED',
            'items': [
              {'productId': 'tea', 'quantity': 10}
            ]
          },
        ]),
        useLocalStock: true);
    final snapshot =
        await RoomInventoryService(AdminApiService(ApiService()), store)
            .project(RoomInventorySnapshot.fromJson(fixture()));
    expect(snapshot.totals['tea']!.total, 6);
    expect(snapshot.quantity('tea', null), 0);
    expect(snapshot.quantity('tea', 'a'), 4);
    expect(snapshot.quantity('tea', 'b'), 2);
  });
}
