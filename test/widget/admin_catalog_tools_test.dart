import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/screens/admin/admin_showcase_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_skus_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _AdminApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    return {
      'products': [
        {
          'id': 'masoor-dal',
          'name': 'Masoor Dal',
          'sku': 'old-sku',
          'slug': 'masoor-dal',
          'categoryId': 'pulses',
          'category': {'id': 'pulses', 'name': 'Pulses'},
          'price': 180,
          'stock': 12,
          'isActive': true,
          'isFeatured': false,
        },
      ],
      'pagination': {'page': 1, 'pageSize': 100, 'total': 1},
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
  }
}

void main() {
  testWidgets('showcase manager saves featured product selection',
      (tester) async {
    final api = _AdminApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminShowcaseScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homepage carousel'), findsOneWidget);
    expect(find.text('Masoor Dal'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/products/masoor-dal');
    expect(api.patches.single.$2, {'isFeatured': true});
    expect(find.text('Add carousel image'), findsOneWidget);
  });

  testWidgets('SKU manager saves the edited SKU', (tester) async {
    final api = _AdminApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminSkusScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product SKU manager'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'pulses-masoor-dal-1kg',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/products/masoor-dal');
    expect(api.patches.single.$2, {'sku': 'pulses-masoor-dal-1kg'});
  });
}
