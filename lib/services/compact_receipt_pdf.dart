import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/constants.dart';
import '../models/pos_models.dart';

/// Fixed-pitch, black-only receipt. The layout keeps a safety gutter for
/// Windows thermal drivers, which often clip the last few millimetres.
class CompactReceiptPdf {
  static Future<pw.Font>? _font;

  static Future<pw.Font> _loadFont() async {
    try {
      return pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf'));
    } catch (error) {
      // A stale/partial release bundle must not prevent an invoice from being
      // prepared.  The bundled PDF font is preferred, but Helvetica keeps the
      // English receipt printable while the next sync/rebuild restores it.
      debugPrint('Receipt font unavailable; using PDF fallback: $error');
      return pw.Font.helvetica();
    }
  }

  static Future<Uint8List> create(PosSale sale, int width) async {
    final font = await (_font ??= _loadFont());
    // 28 columns fit inside the real printable area of both common 58 mm
    // printers and leave enough room for the right-aligned Amount column.
    final columns = width == 58 ? 28 : 42;
    final size = width == 58 ? 6.5 : 7.5;
    final lines = <String>[];
    void text(String value, {bool center = false}) {
      // Split long POS codes, names and monetary amounts without clipping.
      for (final raw in value.split('\n')) {
        var rest = raw;
        while (rest.length > columns) {
          var end = rest.lastIndexOf(' ', columns);
          if (end < columns ~/ 2) end = columns;
          lines.add(rest.substring(0, end));
          rest = rest.substring(end).trimLeft();
        }
        lines.add(center ? rest.padLeft((columns + rest.length) ~/ 2) : rest);
      }
    }

    void pair(String label, String amount) {
      if (label.length + amount.length + 1 > columns) {
        text(label);
        text(amount.padLeft(columns));
      } else {
        text(label + amount.padLeft(columns - label.length));
      }
    }

    void itemHeader() {
      final nameWidth = width == 58 ? 15 : 26;
      final quantityWidth = width == 58 ? 5 : 6;
      final amountWidth = columns - nameWidth - quantityWidth;
      text(
        'Product'.padRight(nameWidth) +
            'Qty'.padLeft(quantityWidth) +
            'Amount'.padLeft(amountWidth),
      );
    }

    void itemRow(PosSaleItem item) {
      final nameWidth = width == 58 ? 15 : 26;
      final quantityWidth = width == 58 ? 5 : 6;
      final amountWidth = columns - nameWidth - quantityWidth;
      final quantity = item.weightGrams == null
          ? '${item.quantity}'
          : '${item.weightGrams}g';
      var remaining = item.productName.trim();
      var first = true;
      while (remaining.isNotEmpty) {
        var end = remaining.length <= nameWidth
            ? remaining.length
            : remaining.lastIndexOf(' ', nameWidth);
        if (end <= 0) end = remaining.length.clamp(1, nameWidth);
        final part = remaining.substring(0, end).trimRight();
        remaining = remaining.substring(end).trimLeft();
        if (first) {
          text(
            part.padRight(nameWidth) +
                quantity.padLeft(quantityWidth) +
                item.lineTotal.toStringAsFixed(2).padLeft(amountWidth),
          );
          first = false;
        } else {
          text(part);
        }
      }
    }

    String receiptDate(DateTime date) {
      final local = date.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      return '${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';
    }

    final rule = '-' * columns;
    text('RAM PRASAD KIRANA STORE', center: true);
    text('PAN No: ${AppConstants.storePanNumber}', center: true);
    text('INVOICE', center: true);
    text(rule);
    text('Inv No: ${sale.invoiceNumber ?? sale.receiptNumber}');
    text('Date: ${receiptDate(sale.createdAt)}');
    text(rule);
    itemHeader();
    text(rule);
    for (final item in sale.items) {
      itemRow(item);
    }
    text(rule);
    pair('Total', sale.total.toStringAsFixed(2));
    pair('Discount', '-${sale.discount.toStringAsFixed(2)}');
    final paid =
        sale.paidAmount ?? (sale.paymentStatus == 'COMPLETED' ? sale.total : 0);
    pair('Balance',
        (sale.outstandingAmount ?? sale.total - paid).toStringAsFixed(2));
    text('${sale.paymentMethod} / ${sale.paymentStatus}');
    text(rule);
    text('Thank you for shopping with us', center: true);
    final document = pw.Document();
    final lineHeight = size * 1.4;
    document.addPage(pw.Page(
      pageFormat: PdfPageFormat(width * PdfPageFormat.mm,
          (lines.length + 2) * lineHeight + 12 * PdfPageFormat.mm,
          marginLeft: 3 * PdfPageFormat.mm,
          marginRight: 3 * PdfPageFormat.mm,
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm),
      build: (_) => pw.Center(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              pw.SizedBox(
                height: lineHeight,
                child: pw.Text(line,
                    style: pw.TextStyle(
                        font: font, fontSize: size, color: PdfColors.black)),
              ),
          ],
        ),
      ),
    ));
    return document.save();
  }
}
