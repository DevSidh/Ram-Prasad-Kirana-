import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/services/pos_receipt_service.dart';
import 'package:freshharvest_grocery/services/pos_timing.dart';
import 'package:freshharvest_grocery/services/readable_bill_pdf.dart';
import 'checkout_print_pipeline_test.dart' show fixtureSale;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'render isolated receipts and measure the previous and new preparation paths',
      () async {
    final output = Directory('tmp/pdfs')..createSync(recursive: true);
    final cache =
        await Directory.systemTemp.createTemp('receipt-visual-cache-');
    PosReceiptService.cacheDirectoryOverride = cache;
    try {
      BillingStrings.languageCode = 'en';
      final sale = fixtureSale(count: 10);
      final before = Stopwatch()..start();
      await ReadableBillPdf.create(
          number: sale.receiptNumber,
          date: sale.createdAt,
          customerName: sale.customerName,
          customerPhone: sale.customerPhone,
          items: [
            for (final i in sale.items)
              (
                item: i.productName,
                quantity: '${i.quantity}',
                amount: i.lineTotal
              )
          ],
          subtotal: sale.subtotal,
          discount: sale.discount,
          vat: sale.vatAmount,
          total: sale.total,
          method: sale.paymentMethod,
          status: sale.paymentStatus,
          paid: sale.paidAmount,
          due: sale.outstandingAmount,
          paperWidthMm: 58);
      before.stop();
      PosReceiptService.clearMemoryCache();
      final fresh = Stopwatch()..start();
      final bytes = await PosReceiptService.createPdf(sale, paperWidthMm: 58);
      fresh.stop();
      await File('${output.path}/receipt-58-en.pdf').writeAsBytes(bytes);
      final reuse = Stopwatch()..start();
      final second = await PosReceiptService.createPdf(sale, paperWidthMm: 58);
      reuse.stop();
      expect(second, orderedEquals(bytes));
      for (final width in [58, 80]) {
        final long = fixtureSale(
            id: 'POS-LONG-$width',
            count: 99999,
            name:
                'Extra long product description for a large family size Bhujiya packet with details');
        final data =
            await PosReceiptService.createPdf(long, paperWidthMm: width);
        await File('${output.path}/receipt-$width-long.pdf').writeAsBytes(data);
        expect(PosReceiptService.formatForBytes(data, width).height,
            greaterThan(100));
      }
      BillingStrings.languageCode = 'ne';
      final ne = await PosReceiptService.createPdf(
          fixtureSale(id: 'POS-NEPALI', name: 'भुजिया विशेष ठूलो प्याकेट'),
          paperWidthMm: 58);
      await File('${output.path}/receipt-58-ne.pdf').writeAsBytes(ne);
      await File('${output.path}/performance.json').writeAsString(jsonEncode({
        'fixture': 'one product, qty10, rate110, discount10, VAT13%, paid50',
        'previousShapedRendererMs': before.elapsedMicroseconds / 1000,
        'newColdPreparationIncludingDiskCacheMs':
            fresh.elapsedMicroseconds / 1000,
        'reuseMs': reuse.elapsedMicroseconds / 1000,
        'stagesMicroseconds': PosTiming.samples,
        'physicalPrinterMeasured': false,
      }));
      // ignore: avoid_print
      print(await File('${output.path}/performance.json').readAsString());
    } finally {
      BillingStrings.languageCode = 'en';
      PosReceiptService.clearMemoryCache();
      PosReceiptService.cacheDirectoryOverride = null;
      await cache.delete(recursive: true);
    }
  });
}
