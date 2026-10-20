import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order.dart';

class OrderInvoiceService {
  static const _nepalOffset = Duration(hours: 5, minutes: 45);
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static Future<Uint8List> createPdf(Order order) async {
    final document = pw.Document();
    final createdAt = DateTime.parse(order.createdAt).toUtc().add(_nepalOffset);
    final address = order.address;
    final addressLines = [
      address.street,
      if (address.landmark?.trim().isNotEmpty == true) address.landmark!.trim(),
      [address.city, address.province]
          .where((part) => part.trim().isNotEmpty)
          .join(', '),
      'Nepal',
    ].where((line) => line.trim().isNotEmpty);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (context) => [
          pw.Text(
            'Ram prasad kirana store',
            style: pw.TextStyle(
              fontSize: 21,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#146B43'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Janakpur, Nepal'),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ORDER INVOICE',
                    style: const pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Order: ${order.orderNumber}'),
                  pw.Text('Date: ${_nepalDate(createdAt)} (NPT)'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Payment: ${_paymentMethod(order.paymentMethod)}'),
                  pw.Text('Status: ${order.status.replaceAll('_', ' ')}'),
                  pw.Text('Payment status: ${order.paymentStatus}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F1F7F3'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DELIVER TO',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#146B43'),
                  ),
                ),
                pw.SizedBox(height: 4),
                if (address.fullName.trim().isNotEmpty)
                  pw.Text(address.fullName),
                if (address.phone.trim().isNotEmpty)
                  pw.Text('Phone: ${address.phone}'),
                for (final line in addressLines) pw.Text(line),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColor.fromHex('#DDE5DF')),
              bottom: pw.BorderSide(color: PdfColor.fromHex('#AAB8AF')),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.7),
            },
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromHex('#E9F2EC')),
                children: [
                  _cell('Item', bold: true),
                  _cell('Qty', bold: true, align: pw.TextAlign.right),
                  _cell('Unit price', bold: true, align: pw.TextAlign.right),
                  _cell('Amount', bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (final item in order.items)
                pw.TableRow(
                  children: [
                    _cell('${item.product.name}\n${item.product.weight}'),
                    _cell('${item.quantity}', align: pw.TextAlign.right),
                    _cell(_currency(item.unitPrice), align: pw.TextAlign.right),
                    _cell(_currency(item.totalPrice),
                        align: pw.TextAlign.right),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 235,
              child: pw.Column(
                children: [
                  _totalRow('Subtotal', order.subtotal),
                  if (order.discount > 0)
                    _totalRow('Discount', -order.discount),
                  if (order.deliveryFee > 0)
                    _totalRow('Delivery charge', order.deliveryFee),
                  if (order.tip > 0) _totalRow('Tip', order.tip),
                  pw.Divider(color: PdfColor.fromHex('#AAB8AF')),
                  _totalRow('Total (NPR)', order.total, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Center(
            child: pw.Text(
              'Thank you for shopping with us.',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#52635A'),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'All amounts are in Nepalese Rupees (NPR).',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
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

  static String _currency(double amount, {String prefix = 'Rs. '}) =>
      '$prefix${_formatNepalAmount(amount)}';

  static String _nepalDate(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day.toString().padLeft(2, '0')} '
        '${_months[date.month - 1]} ${date.year}, '
        '$hour:$minute $period';
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
