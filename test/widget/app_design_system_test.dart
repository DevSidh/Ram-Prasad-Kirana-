import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/core/theme.dart';
import 'package:freshharvest_grocery/core/theme/app_theme_extension.dart';
import 'package:freshharvest_grocery/core/widgets/app_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final isDark in [true, false]) {
    testWidgets(
      'shared design widgets render and respond in ${isDark ? 'dark' : 'light'} theme',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        var quantity = 2;
        var retryCount = 0;
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(
              body: AppBackground(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GlassCard(
                        child: Column(
                          children: [
                            AppTextField(
                              controller: controller,
                              hintText: 'Search items',
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Continue',
                              onPressed: () {},
                            ),
                            const SizedBox(height: 8),
                            OutlineButton(
                              label: 'Details',
                              onPressed: () {},
                            ),
                            const SizedBox(height: 8),
                            QuantityStepper(
                              value: quantity,
                              minimum: 1,
                              onDecrement: () => quantity--,
                              onIncrement: () => quantity++,
                              decreaseLabel: 'Decrease',
                              increaseLabel: 'Increase',
                              quantityLabel: 'Item quantity',
                            ),
                            const SizedBox(height: 8),
                            NoticeBanner(
                              message: 'Unable to load items',
                              retryLabel: 'Retry',
                              onRetry: () => retryCount++,
                            ),
                            const SizedBox(height: 8),
                            CircleIconButton(
                              icon: Icons.search,
                              tooltip: 'Search',
                              onPressed: () {},
                            ),
                            CategoryBubble(
                              label: 'Pantry',
                              icon: const Icon(Icons.rice_bowl),
                              onTap: () {},
                              selected: true,
                            ),
                            const SectionHeader(title: 'Popular near you'),
                            const ShimmerBox(width: 180, height: 24),
                            ErrorState(
                              title: 'Could not load',
                              message: 'Check the connection and retry.',
                              retryLabel: 'Retry',
                              onRetry: () => retryCount++,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(GlassCard), findsOneWidget);
        expect(find.byType(AppTextField), findsOneWidget);
        expect(find.byType(QuantityStepper), findsOneWidget);
        expect(find.byType(ShimmerBox), findsOneWidget);
        expect(
          AppThemeExtension.of(tester.element(find.byType(GlassCard)))
              .accentAmber,
          const Color(0xFFFBBF24),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Increase'));
        await tester.pump();
        expect(quantity, 3);

        await tester.tap(find.text('Retry').first);
        await tester.pump();
        expect(retryCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
