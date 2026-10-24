import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/pos_receipt_service.dart';

void main() {
  final sale = PosSale(
    id: 'sale-1',
    receiptNumber: 'POS-TEST-1',
    customerName: 'Shopper',
    customerPhone: null,
    status: 'COMPLETED',
    paymentMethod: 'CASH',
    paymentStatus: 'COMPLETED',
    subtotal: 45,
    discount: 5,
    total: 40,
    refundedAmount: 0,
    createdAt: DateTime(2026, 10, 24, 12, 30),
    items: const [
      PosSaleItem(
        id: 'line-1',
        productId: 'product-1',
        productName: 'Rice',
        sku: 'RICE-1',
        quantity: 2,
        weightGrams: null,
        unitPrice: 22.5,
        lineTotal: 45,
      ),
    ],
  );

  test('creates a PDF and uses the selected receipt width', () async {
    final format58 = PosReceiptService.pageFormat(sale, paperWidthMm: 58);
    final format80 = PosReceiptService.pageFormat(sale, paperWidthMm: 80);
    expect(format58.width, lessThan(format80.width));

    final bytes = await PosReceiptService.createPdf(
      sale,
      paperWidthMm: 80,
    );
    expect(utf8.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('rejects unsupported thermal paper widths', () {
    expect(
      () => PosReceiptService.pageFormat(sale, paperWidthMm: 72),
      throwsArgumentError,
    );
  });
}
