import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/widgets/home_greeting_diya.dart';

void main() {
  testWidgets('shows the supplied animated diya in a contained greeting slot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeGreetingDiya(),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
        image.image,
        isA<AssetImage>().having(
          (asset) => asset.assetName,
          'assetName',
          'assets/images/home_diya.webp',
        ));
    expect(image.fit, BoxFit.contain);
    expect(image.gaplessPlayback, isTrue);
    expect(tester.getSize(find.byType(HomeGreetingDiya)), const Size(58, 54));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
