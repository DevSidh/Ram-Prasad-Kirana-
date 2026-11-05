import 'dart:io';

import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

/// Configuration for isolated fixtures only; never accepts an output path.
class PerformanceFixtures {
  PerformanceFixtures({required this.label, required this.billCount}) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(label)) {
      throw ArgumentError.value(label, 'PERF_LABEL',
          'Use 1–64 letters, numbers, underscores or hyphens.');
    }
    if (billCount < 0 || billCount > 100000) {
      throw ArgumentError.value(
          billCount, 'PERF_BILLS', 'Must be between 0 and 100000.');
    }
  }

  static const catalogueSize = 2000;
  static const initialStock = 10000;
  final String label;
  final int billCount;

  int productIndexForBill(int index) => index % catalogueSize;

  int expectedStock(int productIndex) =>
      initialStock -
      billCount ~/ catalogueSize -
      (productIndex < billCount % catalogueSize ? 1 : 0);
}

/// Validates fresh disk stock inside the same lock that commits the fixture sale.
Future<File> savePerformanceSale({
  required LocalBillingStore billing,
  required OfflinePosStore store,
  required String requestId,
  required String productId,
}) =>
    billing.saveBill(
      record: {
        'date': '2026-11-03T06:00:00Z',
        'total': 10.25,
        'items': [
          {'productId': productId, 'quantity': 1}
        ],
      },
      requestId: requestId,
      ownerId: 'fixture',
      queueForSync: false,
      uploadPayload: {},
      validate: () async {
        final products = await store.readCatalog(freshStock: true);
        final matches = products.where((product) => product.id == productId);
        if (matches.length != 1 || matches.single.available < 1) {
          throw StateError(
              'Fixture product is missing or has insufficient stock.');
        }
      },
    );
