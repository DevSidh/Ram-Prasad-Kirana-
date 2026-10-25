import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/order_time.dart';

void main() {
  test('formats order creation timestamps in the device timezone', () {
    final formatted = formatOrderPlacedAt('2026-10-10T08:00:00.000Z');

    expect(
      formatted,
      matches(RegExp(r'^\d{1,2} [A-Z][a-z]{2} 2026 · \d{1,2}:\d{2} [AP]M$')),
    );
  });

  test('reports unavailable timestamps without using the current time', () {
    expect(formatOrderPlacedAt(null), 'Time unavailable');
    expect(formatOrderPlacedAt('not-a-date'), 'Time unavailable');
  });
}
