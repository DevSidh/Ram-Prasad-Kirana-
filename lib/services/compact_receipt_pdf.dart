import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/constants.dart';
import '../models/pos_models.dart';

/// Fixed-pitch, black-only receipt. 48mm printable area on 58mm rolls.
class CompactReceiptPdf {
  static Future<ByteData>? _font;
  static Future<Uint8List> create(PosSale sale, int width) async {
    final font = pw.Font.ttf(await (_font ??=
        rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf')));
    final columns = width == 58 ? 32 : 44;
    final size = width == 58 ? 7.0 : 7.5;
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

    final rule = '-' * columns;
    text('RAM PRASAD KIRANA STORE', center: true);
    text('PAN No: ${AppConstants.storePanNumber}', center: true);
    text('INVOICE', center: true);
    text(rule);
    text('Inv No: ${sale.invoiceNumber ?? sale.receiptNumber}');
    text('POS: ${sale.receiptNumber}');
    text('Date: ${sale.createdAt.toLocal().toString().substring(0, 16)}');
    if (sale.customerName?.isNotEmpty == true) text(sale.customerName!);
    if (sale.customerPhone?.isNotEmpty == true) text(sale.customerPhone!);
    text(rule);
    pair('Product', 'Price');
    text(rule);
    for (final item in sale.items) {
      pair(item.productName, item.lineTotal.toStringAsFixed(2));
      text(
          '  ${item.weightGrams == null ? item.quantity : '${item.weightGrams}g'} x ${item.unitPrice.toStringAsFixed(2)}${item.weightGrams == null ? '' : '/kg'}');
    }
    text(rule);
    pair('Total', sale.subtotal.toStringAsFixed(2));
    pair('Discount', '-${sale.discount.toStringAsFixed(2)}');
    if (sale.vatRate != 0 || sale.vatAmount != 0) {
      pair('VAT ${sale.vatRate.toStringAsFixed(2)}%',
          sale.vatAmount.toStringAsFixed(2));
    }
    text(rule);
    pair('Net Payable NPR', sale.total.toStringAsFixed(2));
    final paid =
        sale.paidAmount ?? (sale.paymentStatus == 'COMPLETED' ? sale.total : 0);
    pair('Paid', paid.toStringAsFixed(2));
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
          marginLeft: 5 * PdfPageFormat.mm,
          marginRight: 5 * PdfPageFormat.mm,
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm),
      build: (_) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        for (final line in lines)
          pw.SizedBox(
              height: lineHeight,
              child: pw.Text(line,
                  style: pw.TextStyle(
                      font: font, fontSize: size, color: PdfColors.black)))
      ]),
    ));
    return document.save();
  }
}
