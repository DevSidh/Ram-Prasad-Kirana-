import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../models/pos_models.dart';

class PosReceiptService {
  static PdfPageFormat pageFormat(
    PosSale sale, {
    required int paperWidthMm,
  }) {
    if (paperWidthMm != 58 && paperWidthMm != 80) {
      throw ArgumentError.value(paperWidthMm, 'paperWidthMm');
    }
    final charactersPerLine = paperWidthMm == 58 ? 22 : 34;
    final contentLines = sale.items.fold<int>(
      0,
      (count, item) =>
          count +
          math
              .max(
                1,
                (item.productName.length / charactersPerLine).ceil(),
              )
              .toInt() +
          1,
    );
    final heightMm = 72 + contentLines * 5.4;
    return PdfPageFormat(
      paperWidthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 3 * PdfPageFormat.mm,
    );
  }

  static Future<Uint8List> createPdf(
    PosSale sale, {
    required int paperWidthMm,
  }) async {
    final format = pageFormat(sale, paperWidthMm: paperWidthMm);
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Ram Prasad General Store',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: paperWidthMm == 58 ? 10 : 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Receipt ${sale.receiptNumber}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              sale.createdAt.toLocal().toString().substring(0, 16),
              style: const pw.TextStyle(fontSize: 8),
            ),
            if (sale.customerName?.isNotEmpty == true)
              pw.Text(
                'Customer: ${sale.customerName}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            pw.Divider(),
            for (final item in sale.items) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      item.productName,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Text(
                    '${AppConstants.currencySymbol}'
                    '${item.lineTotal.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Text(
                item.weightGrams == null
                    ? '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}'
                    : '${item.weightGrams} g x ${item.unitPrice.toStringAsFixed(2)}/kg',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 3),
            ],
            pw.Divider(),
            _totalRow('Subtotal', sale.subtotal),
            if (sale.discount > 0) _totalRow('Discount', -sale.discount),
            pw.SizedBox(height: 4),
            _totalRow('TOTAL', sale.total, bold: true),
            pw.SizedBox(height: 5),
            pw.Text(
              'Payment: ${sale.paymentMethod}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Thank you for shopping with us!',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _totalRow(String label, double amount, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 10 : 8,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(
          '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
          style: style,
        ),
      ],
    );
  }
}
