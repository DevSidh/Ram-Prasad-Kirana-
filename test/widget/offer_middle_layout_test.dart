import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/models/store_offer.dart';
import 'package:freshharvest_grocery/widgets/offer_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(360, 640), Size(440, 956)]) {
    testWidgets('offer content fits ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final offer = StoreOffer(
        enabled: true,
        percent: 50,
        maxDiscount: 100,
        code: 'FESTIVAL50',
        id: 'offer-1',
        endsAt: DateTime.now().add(const Duration(hours: 5)),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: OfferPopup(offer: offer),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('FESTIVAL SPECIAL'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('FESTIVAL50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
