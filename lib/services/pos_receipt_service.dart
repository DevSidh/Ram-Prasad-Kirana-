import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../models/pos_models.dart';
import '../models/fonepay_payment_request.dart';
import 'invoice_pdf_builder.dart';
import 'readable_bill_pdf.dart';
import 'compact_receipt_pdf.dart';
import '../core/billing_strings.dart';
import 'pos_timing.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class PosReceiptService {
  static final _prepared = <String, Future<Uint8List>>{};
  static Directory? cacheDirectoryOverride;
  static void clearMemoryCache() => _prepared.clear();
  static PdfPageFormat formatForBytes(Uint8List bytes, int width) {
    final match = RegExp(
            r'/MediaBox\s*\[\s*0(?:\.0)?\s+0(?:\.0)?\s+([\d.]+)\s+([\d.]+)\s*\]')
        .firstMatch(latin1.decode(bytes));
    if (match == null) {
      throw const FormatException('The receipt page size is missing.');
    }
    final actualWidth = double.parse(match[1]!);
    if ((actualWidth - width * PdfPageFormat.mm).abs() > .1) {
      throw const FormatException(
          'Receipt width does not match printer settings.');
    }
    return PdfPageFormat(actualWidth, double.parse(match[2]!));
  }

  static Future<Uint8List> createInvoicePdf(PosSale sale,
      {FonepayPaymentRequest? fonepay}) async {
    _validateFonepay(sale, fonepay);
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
      paymentInstructions: fonepay == null ? null : _fonepayQr(fonepay),
      paidAmount: sale.paidAmount ??
          (sale.paymentStatus == 'COMPLETED' ? sale.total : 0),
      outstandingAmount: sale.outstandingAmount ??
          (sale.total -
                  (sale.paidAmount ??
                      (sale.paymentStatus == 'COMPLETED' ? sale.total : 0)))
              .clamp(0, sale.total)
              .toDouble(),
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
    final heightMm = 77 + contentLines * 5.4;
    return PdfPageFormat(
      paperWidthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 3 * PdfPageFormat.mm,
    );
  }

  static Future<Uint8List> createPdf(
    PosSale sale, {
    required int paperWidthMm,
    FonepayPaymentRequest? fonepay,
    bool? nepaliOverride,
  }) async {
    _validateFonepay(sale, fonepay);
    if (paperWidthMm != 58 && paperWidthMm != 80) {
      throw ArgumentError.value(paperWidthMm, 'paperWidthMm');
    }
    await BillingStrings.load();
    final nepali = nepaliOverride ?? BillingStrings.isNepali;
    // Include every receipt field, language and layout revision: revised
    // balances and paper settings must never reuse a stale PDF.
    final key = sha256
        .convert(utf8.encode(jsonEncode([
          'compact-v1',
          AppConstants.storePanNumber,
          paperWidthMm,
          nepali,
          sale.toReceiptJson(),
          fonepay?.reference,
          fonepay?.qrPayload,
        ])))
        .toString();
    if (_prepared.containsKey(key)) return _prepared[key]!;
    if (_prepared.length >= 32) _prepared.remove(_prepared.keys.first);
    final work = _cached(sale, paperWidthMm, fonepay, key, nepali);
    _prepared[key] = work;
    try {
      return await work;
    } catch (_) {
      _prepared.remove(key);
      rethrow;
    }
  }

  static Future<Uint8List> _cached(PosSale sale, int paperWidthMm,
      FonepayPaymentRequest? fonepay, String key, bool nepali) async {
    Directory? directory;
    try {
      directory = cacheDirectoryOverride ??
          Directory(
              '${(await getApplicationSupportDirectory()).path}/receipt_cache');
      final file = File('${directory.path}/$key.pdf');
      final checksum = File('${file.path}.sha256');
      if (await file.exists() && await checksum.exists()) {
        final bytes = await file.readAsBytes();
        if (sha256.convert(bytes).toString() == await checksum.readAsString() &&
            bytes.length > 5 &&
            String.fromCharCodes(bytes.take(5)) == '%PDF-') {
          return bytes;
        }
      }
    } on MissingPluginException {/* Unit fixtures have no path provider. */}
    final bytes = await PosTiming.measure('receipt_generation', () async {
      if (fonepay == null &&
          !nepali &&
          ![
            sale.customerName,
            ...sale.items.map((i) => i.productName)
          ].any((s) => s != null && RegExp(r'[\u0900-\u097f]').hasMatch(s))) {
        return CompactReceiptPdf.create(sale, paperWidthMm);
      }
      return _createShaped(sale, paperWidthMm, fonepay, nepali);
    });
    if (directory != null) {
      await directory.create(recursive: true);
      final file = File('${directory.path}/$key.pdf');
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
      await File('${file.path}.sha256')
          .writeAsString(sha256.convert(bytes).toString(), flush: true);
    }
    return bytes;
  }

  static Future<Uint8List> _createShaped(PosSale sale, int paperWidthMm,
      FonepayPaymentRequest? fonepay, bool nepali) async {
    // The measured text renderer determines the roll length from the actual
    // wrapped rows, for English and Nepali on both supported paper widths.
    return ReadableBillPdf.create(
      nepaliOverride: nepali,
      number: sale.receiptNumber,
      date: sale.createdAt,
      customerName: sale.customerName,
      customerPhone: sale.customerPhone,
      items: [
        for (final item in sale.items)
          (
            item: item.productName,
            quantity: item.weightGrams == null
                ? '${item.quantity}'
                : '${item.weightGrams} g',
            amount: item.lineTotal
          )
      ],
      subtotal: sale.subtotal,
      discount: sale.discount,
      vat: sale.vatAmount,
      total: sale.total,
      method: sale.paymentMethod,
      status: sale.paymentStatus,
      paid: sale.paidAmount ??
          (sale.paymentStatus == 'COMPLETED' ? sale.total : 0),
      due: sale.outstandingAmount,
      paperWidthMm: paperWidthMm,
      paymentInstructions: fonepay == null
          ? null
          : _fonepayQr(fonepay, size: paperWidthMm == 58 ? 104 : 135),
    );
  }

  static void _validateFonepay(PosSale sale, FonepayPaymentRequest? request) {
    if (request != null && !request.matchesPayableBill(sale)) {
      throw StateError(
          'This Fonepay QR is expired, inactive or does not match the saved bill balance. Refresh verification before printing.');
    }
  }

  static pw.Widget _fonepayQr(FonepayPaymentRequest request,
          {double size = 150}) =>
      pw.Column(children: [
        pw.SizedBox(height: 8),
        pw.Text(
            request.isTest
                ? 'SANDBOX TEST - NOT A REAL PAYMENT'
                : 'Pay with Fonepay',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(request.merchantName!, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Bill: ${request.invoiceNumber}',
            style: const pw.TextStyle(fontSize: 7)),
        pw.SizedBox(height: 6),
        pw.Container(
            color: PdfColors.white,
            padding: const pw.EdgeInsets.all(16),
            child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: request.qrPayload!,
                width: size,
                height: size,
                drawText: false)),
        pw.SizedBox(height: 6),
        pw.Text('Payable: NPR ${request.amount}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Ref: ${request.reference}',
            style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Valid until ${request.expiresAt!.toUtc().toIso8601String()}',
            style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Payment unconfirmed. Verify with Fonepay.',
            style: const pw.TextStyle(fontSize: 7)),
      ]);
}
