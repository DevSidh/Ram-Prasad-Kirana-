import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/places_api_service.dart';

class _FakeApiService extends ApiService {
  final List<dynamic> responses;
  final requests = <(String, Map<String, String>?)>[];

  _FakeApiService(this.responses);

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    requests.add((endpoint, queryParams));
    return responses.removeAt(0);
  }
}

void main() {
  test('autocomplete sends locale and map-bias coordinates', () async {
    final api = _FakeApiService([
      {
        'suggestions': [
          {
            'placeId': 'place-123',
            'description': 'Main Road, Janakpur',
          },
          {'placeId': 12, 'description': 'Ignored malformed result'},
        ],
      },
    ]);
    final service = PlacesApiService(api);

    final suggestions = await service.autocomplete(
      input: 'Main Road',
      languageCode: 'ne',
      latitude: 26.72,
      longitude: 85.92,
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.placeId, 'place-123');
    expect(suggestions.single.description, 'Main Road, Janakpur');
    expect(api.requests.single.$1, '/places/autocomplete');
    expect(api.requests.single.$2, {
      'input': 'Main Road',
      'languageCode': 'ne',
      'latitude': '26.72',
      'longitude': '85.92',
    });
  });

  test('place details validate coordinates and preserve the address label',
      () async {
    final api = _FakeApiService([
      {
        'place': {
          'latitude': 26.728,
          'longitude': 85.925,
          'label': 'Main Road, Janakpur, Nepal',
        },
      },
    ]);
    final service = PlacesApiService(api);

    final place = await service.getDetails('place/123');

    expect(api.requests.single.$1, '/places/place%2F123');
    expect(place.latitude, 26.728);
    expect(place.longitude, 85.925);
    expect(place.label, 'Main Road, Janakpur, Nepal');
  });

  test('malformed suggestions and invalid coordinates fail explicitly',
      () async {
    final malformedSuggestions = PlacesApiService(
      _FakeApiService([
        {'suggestions': null},
      ]),
    );
    await expectLater(
      malformedSuggestions.autocomplete(
        input: 'Janakpur',
        languageCode: 'en',
      ),
      throwsFormatException,
    );

    final invalidDetails = PlacesApiService(
      _FakeApiService([
        {
          'place': {
            'latitude': 95,
            'longitude': 85,
          },
        },
      ]),
    );
    await expectLater(
      invalidDetails.getDetails('place-123'),
      throwsFormatException,
    );
  });
}
