import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../models/pos_models.dart';
import 'invoice_pdf_builder.dart';

class PosReceiptService {
  static Future<Uint8List> createInvoicePdf(PosSale sale) async {
    return InvoicePdfBuilder.create(
      invoiceNumber: sale.invoiceNumber ?? sale.receiptNumber,
      date: sale.createdAt,
      customerName: sale.customerName,
      customerPhone: sale.customerPhone,
      items: sale.items
          .map((item) => InvoicePdfLine(
                quantity: item.weightGrams == null
                    ? '${item.quantity}'
                    : '${item.weightGrams} g',
                item: item.productName,
                amount: item.lineTotal,
              ))
          .toList(growable: false),
      subtotal: sale.subtotal,
      discount: sale.discount,
      vatAmount: sale.vatAmount,
      total: sale.total,
      paymentMethod: sale.paymentMethod,
      paymentStatus: sale.paymentStatus,
    );
  }

  // ignore: unused_element
  static Future<Uint8List> _createInvoicePdfLegacy(PosSale sale) async {
    final document = pw.Document();
    final collectedPayments = sale.paymentCollections.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final paid = (sale.paidAmount ??
            (sale.paymentStatus == 'COMPLETED'
                ? sale.total
                : collectedPayments))
        .clamp(0, sale.total)
        .toDouble();
    final due = (sale.outstandingAmount ?? sale.total - paid)
        .clamp(0, sale.total)
        .toDouble();
    const green = PdfColor(0.08, 0.39, 0.25);
    const muted = PdfColor(0.35, 0.39, 0.37);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ram Prasad General Store',
                    style: const pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Retail invoice',
                      style: const pw.TextStyle(color: muted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: const pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('No. ${sale.receiptNumber}'),
                  pw.Text(_invoiceDate(sale.createdAt)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.95, 0.97, 0.95),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: muted,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text(sale.customerName?.trim().isNotEmpty == true
                        ? sale.customerName!.trim()
                        : 'Walk-in customer'),
                    if (sale.customerPhone?.trim().isNotEmpty == true)
                      pw.Text(sale.customerPhone!.trim()),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PAYMENT STATUS',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: muted,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text(sale.paymentStatus.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300),
              bottom: pw.BorderSide(color: PdfColors.grey400),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: green),
                children: [
                  _invoiceCell('ITEM', header: true),
                  _invoiceCell('QTY', header: true, align: pw.TextAlign.right),
                  _invoiceCell('UNIT PRICE',
                      header: true, align: pw.TextAlign.right),
                  _invoiceCell('AMOUNT',
                      header: true, align: pw.TextAlign.right),
                ],
              ),
              for (final item in sale.items)
                pw.TableRow(
                  children: [
                    _invoiceCell(item.productName),
                    _invoiceCell(
                      item.weightGrams == null
                          ? '${item.quantity}'
                          : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg',
                      align: pw.TextAlign.right,
                    ),
                    _invoiceCell(_invoiceMoney(item.unitPrice),
                        align: pw.TextAlign.right),
                    _invoiceCell(_invoiceMoney(item.lineTotal),
                        align: pw.TextAlign.right),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 235,
              child: pw.Column(
                children: [
                  _invoiceTotalRow('Subtotal', sale.subtotal),
                  if (sale.discount > 0)
                    _invoiceTotalRow('Discount', -sale.discount),
                  if (sale.vatAmount > 0)
                    _invoiceTotalRow(
                        'VAT (${sale.vatRate.toStringAsFixed(2)}%)',
                        sale.vatAmount),
                  pw.Divider(color: PdfColors.grey400),
                  _invoiceTotalRow('Total', sale.total, bold: true),
                  _invoiceTotalRow('Amount paid', paid),
                  _invoiceTotalRow('Balance due', due, bold: due > 0),
                ],
              ),
            ),
          ),
          if (sale.paymentCollections.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text('PAYMENT HISTORY',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: green,
                )),
            pw.SizedBox(height: 7),
            for (final payment in sale.paymentCollections)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        child: pw.Text(_invoiceDate(payment.createdAt))),
                    pw.Expanded(child: pw.Text(payment.method)),
                    pw.Text(_invoiceMoney(payment.amount)),
                  ],
                ),
              ),
          ],
          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              'Thank you for shopping with us!',
              style: const pw.TextStyle(color: muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _invoiceCell(
    String text, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: header ? 8 : 9,
            color: header ? PdfColors.white : PdfColors.black,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static pw.Widget _invoiceTotalRow(
    String label,
    double amount, {
    bool bold = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                )),
            pw.Text(_invoiceMoney(amount),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                )),
          ],
        ),
      );

  static String _invoiceMoney(double amount) =>
      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';

  static String _invoiceDate(DateTime value) {
    final date = value.toLocal();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

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
            if (sale.vatAmount > 0)
              _totalRow(
                  'VAT (${sale.vatRate.toStringAsFixed(2)}%)', sale.vatAmount),
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
