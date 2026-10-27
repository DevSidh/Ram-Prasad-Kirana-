import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfLine {
  const InvoicePdfLine({
    required this.quantity,
    required this.item,
    required this.amount,
  });

  final String quantity;
  final String item;
  final double amount;
}

class InvoicePdfBuilder {
  static const ink = PdfColor(0.04, 0.04, 0.04);

  static Future<Uint8List> create({
    required String invoiceNumber,
    required DateTime date,
    required String? customerName,
    required String? customerPhone,
    required List<InvoicePdfLine> items,
    required double subtotal,
    required double discount,
    required double vatAmount,
    required double total,
    required String paymentMethod,
    required String paymentStatus,
    double deliveryOrOther = 0,
  }) async {
    const rule = PdfColor(0.55, 0.57, 0.59);
    final document = pw.Document();
    final showCustomer = (customerName?.trim().isNotEmpty ?? false) ||
        (customerPhone?.trim().isNotEmpty ?? false);
    final localDate = date.toLocal();
    final dateLabel = '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 34, 32, 30),
        build: (_) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'RAM PRASAD GENERAL STORE',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Janakpur, Nepal',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(color: ink, fontSize: 10),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: rule, height: 1),
              pw.SizedBox(height: 10),
              pw.Text(
                'TAX INVOICE',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(color: ink, fontSize: 14),
              ),
              pw.SizedBox(height: 13),
              _meta('Invoice No.', invoiceNumber),
              _meta('Date', dateLabel),
              if (showCustomer) ...[
                _meta(
                  'Customer Name',
                  customerName?.trim().isNotEmpty == true
                      ? customerName!.trim()
                      : 'Walk-in customer',
                ),
                _meta('Phone No.', customerPhone?.trim() ?? ''),
              ],
              pw.SizedBox(height: 12),
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FixedColumnWidth(42),
                  3: const pw.FixedColumnWidth(65),
                  4: const pw.FixedColumnWidth(72),
                },
                border: pw.TableBorder.all(color: rule, width: .45),
                children: [
                  pw.TableRow(
                    children: [
                      _cell('SN', bold: true, center: true),
                      _cell('Item', bold: true, center: true),
                      _cell('Qty', bold: true, center: true),
                      _cell('Price', bold: true, right: true),
                      _cell('Total', bold: true, right: true),
                    ],
                  ),
                  for (var index = 0; index < items.length; index++)
                    pw.TableRow(
                      children: [
                        _cell('${index + 1}', center: true),
                        _cell(items[index].item),
                        _cell(items[index].quantity, center: true),
                        _cell(_money(_unitPrice(items[index])), right: true),
                        _cell(_money(items[index].amount), right: true),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 9),
              _total('Subtotal', subtotal),
              _total('Discount', discount),
              if (deliveryOrOther != 0)
                _total('Delivery / other', deliveryOrOther),
              _total('Tax (VAT)', vatAmount),
              pw.Divider(color: rule, height: 12),
              _total('Grand Total', total, bold: true, size: 12),
              pw.SizedBox(height: 12),
              _meta('Payment Method', _paymentLabel(paymentMethod)),
              _meta('Payment Status', _statusLabel(paymentStatus)),
              pw.Divider(color: rule, height: 15),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with us!',
                  style: const pw.TextStyle(color: ink, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _meta(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 105,
              child: pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: ink)),
            ),
            pw.Text(':', style: const pw.TextStyle(fontSize: 9, color: ink)),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 9, color: ink)),
            ),
          ],
        ),
      );

  static pw.Widget _cell(String value,
          {bool bold = false, bool right = false, bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Text(
          value,
          textAlign: right
              ? pw.TextAlign.right
              : center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: ink,
          ),
        ),
      );

  static pw.Widget _total(String label, double amount,
          {bool bold = false, double size = 9}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      color: ink,
                      fontSize: size,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text(_money(amount),
                style: pw.TextStyle(
                    color: ink,
                    fontSize: size,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  static double _unitPrice(InvoicePdfLine line) {
    final quantity = double.tryParse(line.quantity.replaceAll(',', ''));
    return quantity == null || quantity == 0
        ? line.amount
        : line.amount / quantity;
  }

  static String _money(double amount) => 'Rs. ${amount.toStringAsFixed(2)}';

  static String _paymentLabel(String value) => switch (value.toUpperCase()) {
        'DIGITAL' || 'ESEWA' => 'eSewa',
        'KHALTI' => 'Khalti',
        'CARD' => 'Card',
        'PENDING' || 'UNPAID' => 'Cash / digital',
        _ => 'Cash',
      };

  static String _statusLabel(String value) => switch (value.toUpperCase()) {
        'COMPLETED' || 'PAID' => 'PAID',
        'PARTIAL' => 'PARTIAL',
        _ => 'UNPAID',
      };
}
