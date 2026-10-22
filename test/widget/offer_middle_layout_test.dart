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

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('FESTIVAL50'), findsOneWidget);
      final saleBanner = find.byKey(const ValueKey('diwali-sale-banner'));
      expect(saleBanner, findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('store-animation-animations/diwali_text.lottie'),
        ),
        findsOneWidget,
      );
      final heroImage = tester.widget<Image>(
        find.byKey(const ValueKey('diwali-popup-hero-image')),
      );
      expect(heroImage.image, isA<ResizeImage>());
      expect(
        (heroImage.image as ResizeImage).height,
        (size.height * .31).clamp(130.0, 220.0).round(),
      );
      final diyaImage = tester.widget<Image>(
        find.byKey(const ValueKey('diwali-popup-diya-image')),
      );
      expect(diyaImage.image, isA<ResizeImage>());
      expect((diyaImage.image as ResizeImage).width, 80);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows fixed-value coupon details accurately', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const offer = StoreOffer(
      enabled: true,
      discountType: OfferDiscountType.fixed,
      amount: 50,
      minOrderAmount: 0,
      code: 'DIWALI50',
      id: 'coupon-diwali',
      endsAt: null,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            disableAnimations: true,
          ),
          child: OfferPopup(offer: offer),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Rs. 50'), findsOneWidget);
    expect(find.text('off your order'), findsOneWidget);
    expect(find.text('Claim offer'), findsOneWidget);
    expect(find.text('DIWALI50'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
