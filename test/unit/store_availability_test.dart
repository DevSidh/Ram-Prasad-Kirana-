import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/store_availability.dart';

void main() {
  test('parses store availability and weekly hours from the API', () {
    final availability = StoreAvailability.fromJson({
      'isOrderingEnabled': true,
      'isAcceptingOrders': false,
      'weeklyHours': [
        {
          'day': 1,
          'isOpen': true,
          'openTime': '09:00',
          'closeTime': '21:00',
        },
      ],
      'timeZone': 'Asia/Kathmandu',
      'statusMessage': 'The store is currently closed.',
    });

    expect(availability.isOrderingEnabled, isTrue);
    expect(availability.isAcceptingOrders, isFalse);
    expect(availability.weeklyHours.single.day, 1);
    expect(availability.weeklyHours.single.openTime, '09:00');
    expect(availability.timeZone, 'Asia/Kathmandu');
  });

  test('rejects an incomplete availability payload', () {
    expect(
      () => StoreAvailability.fromJson({'isOrderingEnabled': true}),
      throwsFormatException,
    );
  });
}
