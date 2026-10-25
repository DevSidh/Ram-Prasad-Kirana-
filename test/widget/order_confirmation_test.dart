import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:freshharvest_grocery/core/animation_trials.dart';
import 'package:freshharvest_grocery/models/address.dart';
import 'package:freshharvest_grocery/models/cart_item.dart';
import 'package:freshharvest_grocery/models/order.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/screens/order/order_confirmation_screen.dart';
import 'package:freshharvest_grocery/widgets/diwali_loop.dart';

void main() {
  testWidgets('order confirmation keeps purchased product thumbnails visible',
      (tester) async {
    final product = Product(
      id: 'apple',
      name: 'Apples',
      categoryId: 'fruit',
      price: 120,
      weight: '1 kg',
      stock: 10,
      description: 'Fresh apples',
      imageUrl: '',
    );
    final order = Order(
      id: 'order-1',
      orderNumber: 'FH-123',
      items: [CartItem(product: product, quantity: 2)],
      address: Address(
        id: 'address-1',
        title: 'Home',
        fullName: 'Customer',
        phone: '9800000000',
        city: 'Kathmandu',
        street: 'Main Street',
      ),
      status: 'PLACED',
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      subtotal: 240,
      total: 290,
      createdAt: '2026-10-10T00:00:00.000Z',
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderConfirmationScreen(order: order)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Apples × 2'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('Order placed'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'store-animation-animations/order_success.lottie',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(DotLottieView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed prepaid orders use the payment success animation',
      (tester) async {
    final product = Product(
      id: 'apple',
      name: 'Apples',
      categoryId: 'fruit',
      price: 120,
      weight: '1 kg',
      stock: 10,
      description: 'Fresh apples',
      imageUrl: '',
    );
    final order = Order(
      id: 'order-2',
      orderNumber: 'FH-124',
      items: [CartItem(product: product, quantity: 1)],
      address: Address(
        id: 'address-2',
        title: 'Home',
        fullName: 'Customer',
        phone: '9800000000',
        city: 'Kathmandu',
        street: 'Main Street',
      ),
      status: 'PLACED',
      paymentMethod: 'DIGITAL',
      paymentStatus: 'COMPLETED',
      subtotal: 120,
      total: 170,
      createdAt: '2026-10-10T00:00:00.000Z',
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderConfirmationScreen(order: order)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    if (AnimationTrials.paymentSuccessWebpEnabled) {
      final animation = tester.widget<DiwaliLoop>(find.byType(DiwaliLoop));
      expect(animation.asset, DiwaliLoop.paymentSuccess);
      expect(animation.semanticLabel, 'Payment successfully completed');
      expect(find.byType(DotLottieView), findsNothing);
    } else {
      expect(find.byType(DiwaliLoop), findsNothing);
      expect(
        find.byKey(
          const ValueKey('store-animation-animations/order_success.lottie'),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
