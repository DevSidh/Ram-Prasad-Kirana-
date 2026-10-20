import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/widgets/product_thumbnail.dart';

void main() {
  testWidgets('thumbnail handles an unbounded width within finite constraints',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 280,
            child: ProductThumbnail(
              imageUrl: '',
              size: 280,
              width: double.infinity,
              height: 280,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
  });

  testWidgets('product photography keeps a centered narrow white image area',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ProductThumbnail(
              imageUrl: '',
              size: 100,
              width: 200,
              height: 100,
              imageWidthFactor: .75,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox &&
            widget.width == 150 &&
            widget.height == 100,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.white,
      ),
      findsWidgets,
    );
  });
}
