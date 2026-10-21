import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/places_api_service.dart';

class _PlacesApi extends ApiService {
  _PlacesApi() : super(baseUrl: 'https://store.example/api/v1');

  final requests = <(String, Map<String, dynamic>)>[];

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    requests.add((endpoint, body));
    if (endpoint == '/places/autocomplete') {
      return {
        'suggestions': [
          {
            'placeId': 'ChIJplace-id',
            'label': 'Janakpur, Nepal',
            'primaryText': 'Janakpur',
            'secondaryText': 'Nepal',
          },
        ],
      };
    }
    return {
      'placeId': 'ChIJplace-id',
      'label': 'Janakpur, Nepal',
      'street': 'Main Road',
      'city': 'Janakpur',
      'province': 'Madhesh Province',
      'latitude': 26.728,
      'longitude': 85.925,
    };
  }
}

void main() {
  test('uses Places autocomplete, session, and nearby map coordinates',
      () async {
    final api = _PlacesApi();
    final service = PlacesApiService(api);
    final sessionToken = service.createSessionToken();

    final suggestions = await service.autocomplete(
      'Janakpur',
      sessionToken: sessionToken,
      latitude: 26.728,
      longitude: 85.925,
    );

    expect(suggestions.single.placeId, 'ChIJplace-id');
    expect(suggestions.single.label, 'Janakpur, Nepal');
    expect(api.requests.single.$1, '/places/autocomplete');
    expect(api.requests.single.$2['sessionToken'], sessionToken);
    expect(api.requests.single.$2['locationBias'], {
      'latitude': 26.728,
      'longitude': 85.925,
    });
  });

  test('parses coordinates and address components from place details',
      () async {
    final api = _PlacesApi();
    final service = PlacesApiService(api);

    final details = await service.getDetails(
      'ChIJplace-id',
      sessionToken: service.createSessionToken(),
    );

    expect(details.street, 'Main Road');
    expect(details.city, 'Janakpur');
    expect(details.province, 'Madhesh Province');
    expect(details.latitude, 26.728);
    expect(details.longitude, 85.925);
  });
}
