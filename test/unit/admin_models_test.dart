import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/admin_models.dart';

void main() {
  group('AdminProduct', () {
    test('reads stock from the Prisma inventory relation', () {
      final product = AdminProduct.fromJson({
        'id': 'p-1',
        'name': 'Rice',
        'sku': 'RICE-1',
        'slug': 'rice',
        'categoryId': 'c-1',
        'category': {'id': 'c-1', 'name': 'Staples'},
        'imageUrl': null,
        'price': '125.50',
        'inventory': {'totalStock': 14, 'reservedStock': 2},
        'isActive': true,
        'isBestSeller': true,
      });

      expect(product.price, 125.5);
      expect(product.stock, 14);
      expect(product.categoryName, 'Staples');
      expect(product.isActive, isTrue);
      expect(product.isBestSeller, isTrue);
      expect(product.copyWith(isVendingDrink: true).isBestSeller, isTrue);
    });
  });

  test('AdminDashboard retains the provided aggregate values and recent orders',
      () {
    final dashboard = AdminDashboard.fromJson({
      'products': {'total': 8, 'active': 7, 'outOfStock': 1, 'lowStock': 2},
      'customers': {'total': 19},
      'orders': {'total': 11, 'pending': 2},
      'sales': {'today': 1250, 'total': 9000},
      'recentOrders': [
        {'orderNumber': 'ORD-1', 'status': 'PENDING'},
      ],
    });

    expect(dashboard.products['lowStock'], 2);
    expect(dashboard.customers['total'], 19);
    expect(dashboard.sales['today'], 1250);
    expect(dashboard.recentOrders.single['orderNumber'], 'ORD-1');
  });
}
