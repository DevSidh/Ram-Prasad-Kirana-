import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/pos_models.dart';
import 'ordered_work_queue.dart';

/// Saves the exact bytes sent to printing, without a Save As dialog.
class BillPdfArchiveService {
  BillPdfArchiveService._();
  static final _writes = OrderedWorkQueue();
  static String? rootOverride;

  static String fileName(PosSale sale) {
    final reference = sale.receiptNumber.trim();
    if (reference.isEmpty ||
        reference.length > 180 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(reference)) {
      throw const FormatException(
          'A valid POS code is required to name the bill PDF.');
    }
    return '${reference.startsWith('POS-') ? reference : 'POS-$reference'}.pdf';
  }

  static Future<String?> save(PosSale sale, Uint8List bytes) async {
    if (kIsWeb) return null;
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException('The bill PDF could not be generated.');
    }
    final root = rootOverride ??
        (Platform.isWindows
            ? 'C:/Ramprasad store/bills/pdf'
            : '${(await getApplicationDocumentsDirectory()).path}/FastStore/bills/pdf');
    final name = fileName(sale);
    return _writes.run(() async {
      final directory = Directory(root);
      await directory.create(recursive: true);
      final file = File('${directory.path}/$name');
      final temporary = File('${file.path}.${const Uuid().v4()}.pending');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
      return file.path;
    });
  }
}
