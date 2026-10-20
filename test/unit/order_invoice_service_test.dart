import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/address.dart';
import 'package:freshharvest_grocery/models/cart_item.dart';
import 'package:freshharvest_grocery/models/order.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/services/order_invoice_service.dart';

void main() {
  test('creates a PDF invoice with a readable PDF signature', () async {
    final product = Product(
      id: 'product-1',
      name: 'Rice',
      categoryId: 'pantry',
      price: 125,
      weight: '1 kg',
      stock: 10,
      description: 'Rice',
      imageUrl: '',
    );
    final order = Order(
      id: 'order-1',
      orderNumber: 'RPK-2026-001',
      items: [CartItem(product: product, quantity: 2)],
      address: Address(
        id: 'address-1',
        title: 'Home',
        fullName: 'Test Customer',
        phone: '9800000000',
        province: 'Madhesh',
        city: 'Janakpur',
        street: 'Main Road',
      ),
      status: 'DELIVERED',
      paymentMethod: 'COD',
      paymentStatus: 'COMPLETED',
      subtotal: 250,
      deliveryFee: 40,
      discount: 20,
      total: 270,
      createdAt: '2026-10-20T10:00:00.000Z',
    );

    final bytes = await OrderInvoiceService.createPdf(order);

    expect(bytes.length, greaterThan(500));
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}
