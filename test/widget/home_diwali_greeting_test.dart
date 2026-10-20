import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/widgets/home_diwali_greeting.dart';
import 'package:freshharvest_grocery/widgets/store_animation.dart';

void main() {
  for (final size in const [Size(360, 640), Size(440, 956)]) {
    testWidgets('shows the complete Diwali animation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeDiwaliGreeting(),
            ),
          ),
        ),
      );

      final animation = tester.widget<StoreAnimation>(
        find.byType(StoreAnimation),
      );
      expect(animation.assetPath, 'animations/diwali_greeting.lottie');
      expect(animation.aspectRatio, 600 / 1253);
      expect(animation.loop, isTrue);
      expect(
        find.byKey(
          const ValueKey('store-animation-animations/diwali_greeting.lottie'),
        ),
        findsOneWidget,
      );
      expect(find.text('FESTIVAL OF LIGHT'), findsNothing);
      final animationSize = tester.getSize(find.byType(StoreAnimation));
      expect(animationSize.width, size.width - 32);
      expect(
        animationSize.height,
        (size.width - 32) / (600 / 1253),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dismissing animation keeps festival heading visible',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HomeDiwaliGreeting()),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Dismiss Diwali animation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss Diwali animation'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('FESTIVAL OF LIGHT'), findsOneWidget);
    expect(find.text('Happy Diwali!'), findsNothing);
    expect(
      find.byKey(
        const ValueKey('store-animation-animations/diwali_greeting.lottie'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
