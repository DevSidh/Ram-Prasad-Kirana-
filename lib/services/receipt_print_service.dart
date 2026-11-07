import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pos_models.dart';
import 'bill_pdf_archive_service.dart';
import 'pos_receipt_service.dart';
import 'pos_timing.dart';

class ReceiptPrintService {
  static const preferenceKey = 'pos_receipt_printer_v1';
  static final _active = <String, Future<bool>>{};
  static Future<Printer?> selected() async {
    final raw =
        (await SharedPreferences.getInstance()).getString(preferenceKey);
    return raw == null ? null : Printer.fromMap(jsonDecode(raw) as Map);
  }

  static Future<Printer?> choose(BuildContext context) async {
    final printer = await Printing.pickPrinter(context: context);
    if (printer != null) {
      await (await SharedPreferences.getInstance())
          .setString(preferenceKey, jsonEncode(printer.toMap()));
    }
    return printer;
  }

  /// Concurrent repeated clicks share one submission. Explicit subsequent
  /// reprints are allowed; a spool acknowledgement is not physical printing.
  static Future<bool> print(PosSale sale, int width) {
    final key = '${sale.id}:$width';
    return _active[key] ??= _print(sale, width).whenComplete(() {
      _active.remove(key);
    });
  }

  static Future<bool> _print(PosSale sale, int width) async {
    final Uint8List bytes =
        await PosReceiptService.createPdf(sale, paperWidthMm: width);
    // Archiving is retryable independently; it must never hold up the spooler.
    final printer = await selected();
    final info = await Printing.info();
    return PosTiming.measure('print_submission', () async {
      if (printer != null && info.canPrint && info.directPrint) {
        return Printing.directPrintPdf(
            printer: printer,
            name: BillPdfArchiveService.fileName(sale),
            format: PosReceiptService.formatForBytes(bytes, width),
            dynamicLayout: false,
            onLayout: (_) async => bytes);
      }
      return Printing.layoutPdf(
          name: BillPdfArchiveService.fileName(sale),
          format: PosReceiptService.formatForBytes(bytes, width),
          dynamicLayout: false,
          onLayout: (_) async => bytes);
    });
  }
}
