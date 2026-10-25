import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/widgets/home_diwali_greeting.dart';
import 'package:freshharvest_grocery/widgets/store_animation.dart';

void main() {
  testWidgets('closing the login greeting removes it from Home',
      (tester) async {
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => visible
                ? HomeDiwaliGreeting(
                    isVisible: true,
                    greeting: 'Good evening',
                    userName: 'Asha',
                    onDismiss: () => setState(() => visible = false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(
      tester.widget<StoreAnimation>(find.byType(StoreAnimation)).assetPath,
      'animations/festival_splash.lottie',
    );
    expect(find.text('Good evening, Asha'), findsOneWidget);

    await tester.tap(find.byTooltip('Close Diwali animation'));
    await tester.pump();
    expect(find.byType(HomeDiwaliGreeting), findsNothing);
    expect(find.byTooltip('Close Diwali animation'), findsNothing);
    expect(find.byKey(const ValueKey('home-diwali-replay-tile')), findsNothing);
    expect(find.text('Festival of Lights'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
