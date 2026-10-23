import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/widgets/home_diwali_greeting.dart';
import 'package:freshharvest_grocery/widgets/store_animation.dart';

void main() {
  for (final size in const [Size(360, 640), Size(440, 956)]) {
    testWidgets('opens the full Diwali animation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HomeDiwaliGreeting()),
        ),
      );

      final animation = tester.widget<StoreAnimation>(
        find.byType(StoreAnimation),
      );
      expect(animation.assetPath, 'animations/diwali_greeting.lottie');
      expect(animation.aspectRatio, 600 / 1253);
      expect(animation.loop, isTrue);
      expect(animation.isVisible, isTrue);
      expect(
        find.byKey(
          const ValueKey('store-animation-animations/diwali_greeting.lottie'),
        ),
        findsOneWidget,
      );
      expect(find.text('Hello, there'), findsOneWidget);
      expect(find.textContaining('FESTIVAL OF LIGHTS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pauses when the home tab is not visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeDiwaliGreeting(isVisible: false),
        ),
      ),
    );

    expect(
      tester.widget<StoreAnimation>(find.byType(StoreAnimation)).isVisible,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('closes the entire animation when X is tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HomeDiwaliGreeting()),
      ),
    );

    await tester.tap(find.byTooltip('Close Diwali animation'));
    await tester.pump();

    expect(find.byType(StoreAnimation), findsNothing);
    expect(find.byTooltip('Close Diwali animation'), findsNothing);
    expect(find.textContaining('FESTIVAL OF LIGHTS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
