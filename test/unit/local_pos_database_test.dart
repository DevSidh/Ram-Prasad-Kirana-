import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/local_pos_database.dart';

void main() {
  late Directory directory;
  late LocalPosDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('faststore-pos-db-');
    database = LocalPosDatabase.atPath(
        '${directory.path}${Platform.pathSeparator}pos.sqlite');
    await database.initialize();
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('creates all local-first POS tables', () async {
    expect(
        await database.tableNames(),
        containsAll([
          'products',
          'wholesale_products',
          'drinks_menu',
          'customers',
          'bills',
          'bill_items',
          'refunds',
          'pending_cash',
          'outbox',
          'sync_metadata',
        ]));
  });

  test('indexes and searches the catalog and records tombstones', () async {
    const retail = PosProduct(
      id: 'retail-1',
      name: 'Green tea',
      sku: 'TEA-1',
      barcode: '89010001',
      price: 235,
      unitLabel: 'pcs',
      available: 480,
    );
    const wholesale = PosProduct(
      id: 'wholesale-2',
      name: 'Rice sack',
      sku: 'RICE-25',
      barcode: null,
      price: 2500,
      unitLabel: '25 kg',
      available: 8,
    );
    await database.replaceCatalog([retail, wholesale]);

    expect(await database.searchCatalog('89010001'), [retail]);
    expect(await database.searchCatalog('rice'), [wholesale]);

    await database.replaceCatalog([retail]);
    expect(await database.readCatalog(), [retail]);
  });

  test('persists bill items and idempotent retryable outbox entries', () async {
    final bill = <String, dynamic>{
      'id': 'invoice-1',
      'invoiceNumber': 'RPGS-INV-2026-L-1',
      'date': '2026-11-08T10:00:00.000Z',
      'total': 235,
      'status': 'COMPLETED',
      'syncState': 'pending',
      'items': [
        {
          'productId': 'retail-1',
          'name': 'Green tea',
          'sku': 'TEA-1',
          'quantity': 1,
          'unitPrice': 235,
          'amount': 235,
        },
      ],
    };
    await database.saveBill(bill);
    await database.enqueue(
      id: 'request-1',
      entityType: 'bill',
      entityId: 'invoice-1',
      operation: 'create',
      payload: {'invoiceNumber': bill['invoiceNumber']},
    );
    await database.enqueue(
      id: 'request-1',
      entityType: 'bill',
      entityId: 'invoice-1',
      operation: 'create',
      payload: {'invoiceNumber': bill['invoiceNumber']},
    );

    expect((await database.readBill('invoice-1'))?['total'], 235);
    expect((await database.pendingOutbox()).length, 1);
    await database.updateBillSyncState('invoice-1', 'synced');
    expect((await database.readBill('invoice-1'))?['syncState'], 'synced');
  });

  test('applies delta batches with per-table cursors', () async {
    final cutoff = DateTime.utc(2026, 11, 8);
    await database.applySyncBatch({
      'cutoff': cutoff.toIso8601String(),
      'products': [
        {
          'id': 'retail-2',
          'name': 'Coffee',
          'sku': 'COF-2',
          'barcode': '89020002',
          'price': 120,
          'unitLabel': 'pcs',
          'available': 30,
          'imageUrl': '/image/coffee',
          'isActive': true,
          'updatedAt': cutoff.toIso8601String(),
        },
      ],
      'wholesaleProducts': [
        {
          'id': 'wholesale-3',
          'name': 'Coffee case',
          'sku': 'COF-CASE',
          'price': 1100,
          'stock': 4,
          'unitLabel': 'case',
          'isActive': false,
          'updatedAt': cutoff.toIso8601String(),
        },
      ],
      'drinks': [
        {
          'id': 'drink-1',
          'name': 'Iced tea',
          'sku': 'ICE-1',
          'price': 90,
          'isActive': true,
          'updatedAt': cutoff.toIso8601String(),
        },
      ],
      'customers': [
        {
          'id': 'customer-server-1',
          'profileId': '123',
          'name': 'Mina',
          'email': 'mina@example.com',
          'phone': '9800000001',
          'isActive': true,
          'createdAt': cutoff.toIso8601String(),
          'updatedAt': cutoff.toIso8601String(),
        },
      ],
      'bills': [
        {
          'id': 'server-sale-1',
          'receiptNumber': 'POS-1',
          'invoiceNumber': 'INV-1',
          'status': 'COMPLETED',
          'paymentMethod': 'CASH',
          'paymentStatus': 'PENDING',
          'subtotal': 120,
          'discount': 0,
          'vatRate': 0,
          'vatAmount': 0,
          'total': 120,
          'refundedAmount': 0,
          'createdAt': cutoff.toIso8601String(),
          'updatedAt': cutoff.toIso8601String(),
          'items': [
            {
              'id': 'server-sale-item-1',
              'productId': 'retail-2',
              'productName': 'Coffee',
              'sku': 'COF-2',
              'quantity': 1,
              'unitPrice': 120,
              'lineTotal': 120,
            },
          ],
          'paymentCollections': [],
        },
      ],
      'refunds': [
        {
          'id': 'refund-1',
          'saleId': 'server-sale-1',
          'amount': 10,
          'requestedAt': cutoff.toIso8601String(),
          'updatedAt': cutoff.toIso8601String(),
        },
      ],
      'pendingCash': [
        {
          'id': 'server-sale-2',
          'customerName': 'Mina',
          'amount': 25,
          'updatedAt': cutoff.toIso8601String(),
          'isDeleted': true,
        },
      ],
    });

    expect(await database.searchCatalog('89020002'), hasLength(1));
    expect(await database.searchCatalog('COF-CASE'), isEmpty);
    expect((await database.readCustomers()).single.id, 'customer-server-1');
    expect((await database.readBill('server-sale-1'))?['syncState'], 'synced');
    expect(
        (await database.readBillsPage()).sales.single.items.single.productName,
        'Coffee');
    expect((await database.readPendingPayments()).sales.single.id,
        'server-sale-1');
    expect((await database.readRefunds()).single.id, 'refund-1');
    expect(await database.lastSyncedAt('pending_cash'), cutoff);
  });
}
