import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/scanned_product_barcode.dart';

void main() {
  test('extracts GTIN and dates from human-readable GS1 data', () {
    final result = ScannedProductBarcode.parse(
      '(01)09506000134352(11)261001(17)270101(10)LOT-7',
    );

    expect(result?.value, '09506000134352');
    expect(result?.manufacturedAt, DateTime.utc(2026, 10, 1));
    expect(result?.expiresAt, DateTime.utc(2027, 1, 1));
  });

  test('extracts GS1 dates from raw scanner data with symbol prefix', () {
    final result = ScannedProductBarcode.parse(
      ']C10109506000134352112610011727010110LOT-7',
    );

    expect(result?.value, '09506000134352');
    expect(result?.manufacturedAt, DateTime.utc(2026, 10, 1));
    expect(result?.expiresAt, DateTime.utc(2027, 1, 1));
  });

  test('does not interpret invalid GS1 dates as verified dates', () {
    final result = ScannedProductBarcode.parse(
      '(01)09506000134352(11)261332(17)270230',
    );

    expect(result?.value, '09506000134352');
    expect(result?.manufacturedAt, isNull);
    expect(result?.expiresAt, isNull);
  });

  test('preserves regular barcode values', () {
    expect(
      ScannedProductBarcode.parse('0123456789012')?.value,
      '0123456789012',
    );
    expect(ScannedProductBarcode.parse('abc'), isNull);
  });
}
