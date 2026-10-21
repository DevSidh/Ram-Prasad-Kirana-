import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/widgets/scooter_loading_screen.dart';

void main() {
  testWidgets('loading screen does not display the app logo', (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ScooterLoadingScreen(
          init: () => initialization.future,
          onFinished: (_) {},
          minDuration: const Duration(minutes: 1),
          title: 'FastStore',
          subtitle: 'Janakpur',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('splash-brand-logo')), findsNothing);
    expect(find.byType(Image), findsNothing);

    initialization.complete();
  });
}
