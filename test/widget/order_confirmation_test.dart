import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/address.dart';
import 'package:freshharvest_grocery/models/cart_item.dart';
import 'package:freshharvest_grocery/models/order.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/screens/order/order_confirmation_screen.dart';

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
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
