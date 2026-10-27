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

  test('creates a shareable invoice with partial-payment details', () async {
    final partialSale = PosSale(
      id: 'sale-2',
      receiptNumber: 'POS-TEST-2',
      customerName: 'Customer',
      customerPhone: '9800000000',
      status: 'COMPLETED',
      paymentMethod: 'CASH',
      paymentStatus: 'PARTIAL',
      subtotal: 100,
      discount: 10,
      total: 90,
      refundedAmount: 0,
      createdAt: DateTime(2026, 10, 24, 12, 30),
      paidAmount: 30,
      outstandingAmount: 60,
      paymentCollections: [
        PosPaymentCollection(
          id: 'payment-1',
          amount: 30,
          method: 'CASH',
          note: null,
          createdAt: DateTime(2026, 10, 24, 12, 35),
        ),
      ],
      items: sale.items,
    );

    final bytes = await PosReceiptService.createInvoicePdf(partialSale);

    expect(utf8.decode(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('rejects unsupported thermal paper widths', () {
    expect(
      () => PosReceiptService.pageFormat(sale, paperWidthMm: 72),
      throwsArgumentError,
    );
  });
}
