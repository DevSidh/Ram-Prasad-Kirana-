import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/services/readable_bill_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => BillingStrings.languageCode = 'en');
  for (final width in <int?>[null, 58, 80]) {
    test(
        'Nepali ${width ?? 'A4'} bill shapes text and preserves POS and exact totals',
        () async {
      BillingStrings.languageCode = 'ne';
      final bytes = await ReadableBillPdf.create(
          number: 'POS-NE-1105',
          date: DateTime(2026, 11, 5, 10, 30),
          customerName: 'रामप्रसाद साह',
          customerPhone: '9801234567',
          items: [
            (item: 'चामल · सर्वोत्तम गुणस्तर', quantity: '1250 g', amount: 250),
            (item: 'Fixture soap', quantity: '2', amount: 100)
          ],
          subtotal: 350,
          discount: 20,
          vat: 42.9,
          total: 372.9,
          method: 'CASH',
          status: 'PARTIAL',
          paid: 300,
          due: 72.9,
          paperWidthMm: width);
      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(10000));
      final directory = Directory('tmp/pdfs')..createSync(recursive: true);
      await File('${directory.path}/nepali-${width ?? 'a4'}.pdf')
          .writeAsBytes(bytes);
    });
  }
}
