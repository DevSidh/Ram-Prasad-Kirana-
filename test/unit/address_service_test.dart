import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/models/address.dart';
import 'package:freshharvest_grocery/services/address_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _AddressApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];
  final List<(String, Map<String, dynamic>)> posts = [];
  final List<String> deletes = [];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async =>
      {
        'data': [
          {
            'id': 'address-1',
            'label': 'Home',
            'fullName': 'Ram',
            'phone': '9800000000',
            'province': 'Madhesh',
            'city': 'Janakpur',
            'addressLine1': 'Ward 4',
            'addressLine2': 'Near the market',
            'instructions': 'Call on arrival',
            'isDefault': true,
          },
        ],
      };

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    posts.add((endpoint, body));
    return {
      'data': {'id': 'address-new', ...body}
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
    if (body.length == 1 && body.containsKey('isDefault')) return null;
    return {
      'data': {'id': 'address-1', ...body}
    };
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    deletes.add(endpoint);
    return null;
  }
}

Address _sampleAddress() => Address(
      id: '',
      title: 'Home',
      fullName: 'Ram Prasad',
      phone: '9800000000',
      province: 'Madhesh',
      city: 'Janakpur',
      street: 'Ward 4',
      isDefault: true,
    );

void main() {
  test('maps persisted database address fields to the app model', () async {
    final address = (await AddressService(_AddressApi()).getAddresses()).single;

    expect(address.id, 'address-1');
    expect(address.street, 'Ward 4');
    expect(address.landmark, 'Near the market');
    expect(address.instructions, 'Call on arrival');
    expect(address.isDefault, isTrue);
  });

  test('creates, edits, sets default, and deletes an address', () async {
    final api = _AddressApi();
    final service = AddressService(api);
    final created = await service.createAddress(_sampleAddress());
    final saved = await service.updateAddress(
      Address(
        id: 'address-1',
        title: 'Work',
        fullName: 'Ram Prasad',
        phone: '9800000000',
        province: 'Madhesh',
        city: 'Janakpur',
        street: 'Ward 5',
        isDefault: true,
      ),
    );
    await service.setDefault('address-1');
    await service.deleteAddress('address-1');

    expect(created.id, 'address-new');
    expect(api.posts.single.$1, '/account/addresses');
    expect(api.posts.single.$2['street'], 'Ward 4');
    expect(saved.title, 'Work');
    expect(api.patches[0].$1, '/account/addresses/address-1');
    expect(api.patches[1].$1, '/account/addresses/address-1');
    expect(api.patches[1].$2, {'isDefault': true});
    expect(api.deletes, ['/account/addresses/address-1']);
  });
}
