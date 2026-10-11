git commit -m "Update Ram Prasad General Store app"import 'package:flutter/material.dart';
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
}
