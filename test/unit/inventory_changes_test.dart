import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/inventory_changes.dart';

void main() {
  test('only successful inventory-affecting mutations publish a refresh signal',
      () async {
    var status = 201;
    final api = ApiService(
        baseUrl: 'https://fixture.invalid',
        client: MockClient((request) async => http.Response(
            status >= 400 ? '{"error":"Denied"}' : '{}', status,
            request: request)));
    final initial = InventoryChanges.revision.value;
    await api.post('/admin/billing/sales', {});
    await Future<void>.delayed(Duration.zero);
    expect(InventoryChanges.revision.value, initial + 1);
    status = 200;
    await api.get('/admin/products');
    await Future<void>.delayed(Duration.zero);
    expect(InventoryChanges.revision.value, initial + 1);
    status = 403;
    await expectLater(api.patch('/admin/products/test', {}),
        throwsA(isA<ApiResponseException>()));
    await Future<void>.delayed(Duration.zero);
    expect(InventoryChanges.revision.value, initial + 1);
    status = 200;
    await api.post('/admin/billing/sales/test/exchanges', {});
    await Future<void>.delayed(Duration.zero);
    expect(InventoryChanges.revision.value, initial + 2);
  });
}
