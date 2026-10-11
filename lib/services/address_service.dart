import '../models/address.dart';
import 'api_service.dart';

class AddressService {
  final ApiService _api;

  const AddressService(this._api);

  Future<List<Address>> getAddresses() async {
    final response = await _api.get('/account/addresses');
    if (response is! Map<String, dynamic> || response['data'] is! List) {
      throw Exception('The server returned an invalid address list.');
    }
    return (response['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Address.fromJson)
        .toList();
  }

  Future<Address> createAddress(Address address) async {
    final response = await _api.post('/account/addresses', address.toApiJson());
    return _readAddress(response);
  }

  Future<Address> updateAddress(Address address) async {
    final response = await _api.patch(
      '/account/addresses/${address.id}',
      address.toApiJson(),
    );
    return _readAddress(response);
  }

  Future<void> setDefault(String addressId) async {
    await _api.patch('/account/addresses/$addressId', {'isDefault': true});
  }

  Future<void> deleteAddress(String addressId) async {
    await _api.delete('/account/addresses/$addressId');
  }

  Address _readAddress(dynamic response) {
    if (response is! Map<String, dynamic> ||
        response['data'] is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid delivery address.');
    }
    return Address.fromJson(response['data'] as Map<String, dynamic>);
  }
}
