import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/coupon_quote.dart';

void main() {
  test('parses a valid coupon quote', () {
    final quote = CouponQuote.fromJson({
      'valid': true,
      'code': 'SAVE10',
      'discount': 125,
      'message': 'Coupon applied successfully.',
    });

    expect(quote.valid, isTrue);
    expect(quote.code, 'SAVE10');
    expect(quote.discount, 125);
  });

  test('rejects malformed coupon responses', () {
    expect(
      () => CouponQuote.fromJson({'valid': 'yes'}),
      throwsFormatException,
    );
  });
}
