import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/admin_models.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/billing_customer_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

class _CustomerStore extends OfflinePosStore {
  @override
  Future<List<PosSale>> readOfflineSales() async => List.generate(
      12,
      (index) => PosSale.fromJson({
            'id': 'bill-$index',
            'receiptNumber': 'BILL-$index',
            'createdAt': '2026-11-04T00:00:00Z',
            'total': 10,
            'customerName': index == 0 ? '' : 'Customer $index',
            'customerPhone': '98000000${index.toString().padLeft(2, '0')}',
            'items': [],
          }));
}

AdminCustomer customer(String name, String phone,
        {String id = 'local-customer-test'}) =>
    AdminCustomer.fromJson(
        {'id': id, 'name': name, 'phone': phone, 'isActive': true});

void main() {
  test('exact existing name returns its normalized phone number', () {
    final result = BillingCustomerService.findExact(
        [customer('SS', '+977 9800000000')],
        name: 'ss', phone: '', byName: true);
    expect(result?.phone, '9800000000');
  });
  test('ambiguous names never select an arbitrary phone number', () {
    final contacts = [
      customer('Ram', '9800000000'),
      customer('Ram', '9800000001')
    ];
    expect(
        BillingCustomerService.findExact(contacts,
            name: 'Ram', phone: '', byName: true),
        isNull);
    expect(
        BillingCustomerService.findExact(contacts,
                name: 'Ram', phone: '9800000001')
            ?.phone,
        '9800000001');
  });
  test('phone-only contacts remain visible and duplicate sources are merged',
      () {
    final result = BillingCustomerService.merge(
        [customer('', '9800000000'), customer('Ram', '+9779800000000')]);
    expect(result, hasLength(1));
    expect(result.single.name, 'Ram');
  });
  test('billing contacts include all local history and saved contacts',
      () async {
    final result = await BillingCustomerService.readLocal(_CustomerStore(),
        loadSavedCustomers: () async =>
            [customer('Saved contact', '9700000000')]);
    expect(result, hasLength(13));
    expect(result.any((contact) => contact.phone == '9800000000'), isTrue);
    expect(result.every((contact) => contact.id.startsWith('local-customer-')),
        isTrue);
  });
  test('weight stock preserves grams when caching management products', () {
    final product = AdminProduct.fromJson({
      'id': 'rice',
      'unitLabel': '1 kg',
      'weightStockKg': 5.125,
      'stock': 5
    });
    expect(product.posStockUnits, 5125);
    expect(product.availableStock, 5.125);
  });
}
