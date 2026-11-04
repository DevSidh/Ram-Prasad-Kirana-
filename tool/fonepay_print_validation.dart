// Generates and rasterizes NONPAYABLE TEST fixtures using the app's own printer
// plugin. No merchant API or real bill is accessed.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:printing/printing.dart';
import 'package:freshharvest_grocery/services/pos_receipt_service.dart';
import '../test/fixtures/fonepay_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  final sale = fonepayFixtureSale(), request = fonepayFixtureRequest();
  final outputs = {
    'paid-a4': await PosReceiptService.createInvoicePdf(fonepayFixtureSale(
        paymentMethod: 'FONEPAY',
        paymentStatus: 'COMPLETED',
        paidAmount: 113.01)),
    'paid-thermal80': await PosReceiptService.createPdf(
        fonepayFixtureSale(
            paymentMethod: 'FONEPAY',
            paymentStatus: 'COMPLETED',
            paidAmount: 113.01),
        paperWidthMm: 80),
    'a4': await PosReceiptService.createInvoicePdf(sale, fonepay: request),
    'thermal58': await PosReceiptService.createPdf(sale,
        paperWidthMm: 58, fonepay: request),
    'thermal80': await PosReceiptService.createPdf(sale,
        paperWidthMm: 80, fonepay: request),
  };
  final root = Directory('tmp/pdfs/fonepay-validation');
  await root.create(recursive: true);
  for (final output in outputs.entries) {
    await File('${root.path}/${output.key}.pdf').writeAsBytes(output.value);
    var page = 0;
    await for (final bitmap in Printing.raster(output.value, dpi: 150)) {
      final source = await bitmap.toImage();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
      canvas.drawImage(source, ui.Offset.zero, ui.Paint());
      final flattened =
          await recorder.endRecording().toImage(source.width, source.height);
      final png = await flattened.toByteData(format: ui.ImageByteFormat.png);
      await File('${root.path}/${output.key}-${page++}.png')
          .writeAsBytes(png!.buffer.asUint8List());
      source.dispose();
      flattened.dispose();
    }
    print('Rendered ${output.key}: $page page(s), TEST ONLY');
  }
  exit(0);
}
