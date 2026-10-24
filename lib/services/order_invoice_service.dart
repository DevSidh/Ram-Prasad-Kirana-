import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cart_item.dart';
import '../models/order.dart';

class OrderInvoiceService {
  static const _nepalOffset = Duration(hours: 5, minutes: 45);

  static Future<Uint8List> createPdf(Order order) async {
    final document = pw.Document();
    final createdAt = DateTime.parse(order.createdAt).toUtc().add(_nepalOffset);
    final address = order.address;
    final buyerAddress = [
      address.street,
      if (address.landmark?.trim().isNotEmpty == true) address.landmark!.trim(),
      [address.city, address.province]
          .where((part) => part.trim().isNotEmpty)
          .join(', '),
    ].where((line) => line.trim().isNotEmpty).join(', ');
    final border = PdfColor.fromHex('#343434');
    final headerFill = PdfColor.fromHex('#EEEEEE');
    final invoiceNumber = 'RPGS-${order.orderNumber}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 25),
        build: (context) => [
          pw.Text(
            'RAM PRASAD KIRANA STORE',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 23,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.8),
            columnWidths: {
              0: const pw.FixedColumnWidth(535),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerFill),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Text(
                      'TAX INVOICE',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _strong('Ram Prasad Kirana Store'),
                              pw.Text('Janakpur, Nepal'),
                              pw.Text('Address: __________________________'),
                              pw.Text('Phone: _____________________________'),
                              pw.Text('Email: ______________________________'),
                              pw.SizedBox(height: 4),
                              _identifierRow('VAT No:', ''),
                            ],
                          ),
                        ),
                      ),
                      pw.Container(width: 0.8, height: 112, color: border),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _metaRow('Invoice No:', invoiceNumber),
                              _metaRow('Date:', _invoiceDate(createdAt)),
                              _metaRow('Miti:', '________________'),
                              _metaRow('Transaction:', order.orderNumber),
                              _metaRow('Pay Mode:',
                                  _paymentMethod(order.paymentMethod)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerFill),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: _strong('Buyer Information'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Name: ${address.fullName}'),
                              pw.Text('Address: $buyerAddress'),
                              if (address.phone.trim().isNotEmpty)
                                pw.Text('Phone: ${address.phone}'),
                            ],
                          ),
                        ),
                        _identifierRow('VAT/PAN No:', ''),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.7),
            columnWidths: {
              0: const pw.FixedColumnWidth(32),
              1: const pw.FixedColumnWidth(56),
              2: const pw.FlexColumnWidth(4),
              3: const pw.FixedColumnWidth(48),
              4: const pw.FixedColumnWidth(74),
              5: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerFill),
                children: [
                  _cell('S.N.', bold: true),
                  _cell('HS Code', bold: true),
                  _cell('Particulars', bold: true),
                  _cell('Qty', bold: true, align: pw.TextAlign.right),
                  _cell('Rate', bold: true, align: pw.TextAlign.right),
                  _cell('Amount', bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (var index = 0; index < order.items.length; index++)
                _invoiceItemRow(index + 1, order.items[index]),
            ],
          ),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.7),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.8),
              1: const pw.FlexColumnWidth(0.9),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Amount in words: ${_amountInWords(order.total)}',
                      style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      children: [
                        _totalRow('Sub Total:', order.subtotal),
                        if (order.discount > 0)
                          _totalRow('Discount:', -order.discount),
                        if (order.deliveryFee > 0)
                          _totalRow('Delivery charge:', order.deliveryFee),
                        if (order.tip > 0) _totalRow('Tip:', order.tip),
                        _placeholderTotalRow('VAT / Tax:'),
                        pw.Divider(color: border),
                        _totalRow('Grand Total:', order.total, bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text('E.&O.E.', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _cell(
    String value, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: pw.Text(
          value,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static pw.Widget _strong(String value) => pw.Text(
        value,
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
      );

  static pw.Widget _metaRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 84, child: _strong(label)),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );

  static pw.Widget _identifierRow(String label, String value) => pw.Row(
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 5),
          if (value.isEmpty)
            for (var i = 0; i < 9; i++)
              pw.Container(
                width: 15,
                height: 18,
                margin: const pw.EdgeInsets.only(right: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#343434')),
                ),
              )
          else
            pw.Text(value),
        ],
      );

  static pw.TableRow _invoiceItemRow(int index, CartItem item) => pw.TableRow(
        children: [
          _cell('$index'),
          _cell(''),
          _cell('${item.product.name}\n${item.product.weight}'),
          _cell(
            item.weightGrams == null
                ? '${item.quantity}'
                : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg',
            align: pw.TextAlign.right,
          ),
          _cell(_currency(item.unitPrice), align: pw.TextAlign.right),
          _cell(_currency(item.totalPrice), align: pw.TextAlign.right),
        ],
      );

  static pw.Widget _totalRow(String label, double amount,
          {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              _currency(amount.abs(), prefix: amount < 0 ? '-Rs. ' : 'Rs. '),
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _placeholderTotalRow(String label) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label),
            pw.Text('________________'),
          ],
        ),
      );

  static String _currency(double amount, {String prefix = 'Rs. '}) =>
      '$prefix${_formatNepalAmount(amount)}';

  static String _invoiceDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _amountInWords(double value) {
    final amountInPaise = (value * 100).round();
    final rupees = amountInPaise ~/ 100;
    final paise = amountInPaise % 100;
    final parts = <String>[];
    if (rupees > 0) parts.add('${_integerWords(rupees)} rupees');
    if (paise > 0) parts.add('${_integerWords(paise)} paisa');
    if (parts.isEmpty) parts.add('zero rupees');
    return '${parts.join(' and ').toUpperCase()} ONLY';
  }

  static String _integerWords(int value) {
    const ones = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];
    if (value < 20) return ones[value];
    if (value < 100) {
      return '${tens[value ~/ 10]}${value % 10 == 0 ? '' : ' ${ones[value % 10]}'}';
    }
    if (value < 1000) {
      return '${ones[value ~/ 100]} hundred${value % 100 == 0 ? '' : ' ${_integerWords(value % 100)}'}';
    }
    for (final scale in [
      (10000000, 'crore'),
      (100000, 'lakh'),
      (1000, 'thousand'),
    ]) {
      if (value >= scale.$1) {
        return '${_integerWords(value ~/ scale.$1)} ${scale.$2}'
            '${value % scale.$1 == 0 ? '' : ' ${_integerWords(value % scale.$1)}'}';
      }
    }
    return 'Amount exceeds invoice word format';
  }

  static String _formatNepalAmount(double amount) {
    final fixed = amount.toStringAsFixed(2).split('.');
    final whole = fixed[0];
    if (whole.length <= 3) return '$whole.${fixed[1]}';
    final lastThree = whole.substring(whole.length - 3);
    final prefix = whole.substring(0, whole.length - 3);
    final groupedPrefix = prefix.replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{2})+$)'),
      (_) => ',',
    );
    return '$groupedPrefix,$lastThree.${fixed[1]}';
  }

  static String _paymentMethod(String method) =>
      method.toUpperCase() == 'COD' ? 'Cash on Delivery' : method;
}
