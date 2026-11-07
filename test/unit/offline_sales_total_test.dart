import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

void main() {
  test('offline sales total includes pending and synchronized local bills',
      () async {
    final root = await Directory.systemTemp.createTemp('faststore-offline-total-');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalBillingStore(rootPath: root.path);

    Future<void> write(String invoice, double total, String syncState,
        {String status = 'COMPLETED'}) async {
      await store.writeJson(File('${root.path}/$invoice.json'), {
        'invoiceNumber': invoice,
        'date': '2026-11-07T10:00:00.000Z',
        'status': status,
        'syncState': syncState,
        'total': total,
        'items': const [],
      });
    }

    await write('OFFLINE-1', 125.50, 'local_only');
    await write('OFFLINE-2', 300, 'synced');
    await write('CANCELLED-1', 999, 'local_only', status: 'CANCELLED');

    expect(await OfflinePosStore(billingStore: store).readOfflineSalesTotal(),
        425.50);
  });
}
