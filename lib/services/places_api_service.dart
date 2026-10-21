import 'api_service.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

class PlaceDetails {
  final double latitude;
  final double longitude;
  final String label;

  const PlaceDetails({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class PlacesApiService {
  final ApiService _api;

  const PlacesApiService(this._api);

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String languageCode,
    double? latitude,
    double? longitude,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError('Latitude and longitude must be supplied together.');
    }

    final response = await _api.get(
      '/places/autocomplete',
      queryParams: {
        'input': input,
        'languageCode': languageCode,
        if (latitude != null && longitude != null) ...{
          'latitude': '$latitude',
          'longitude': '$longitude',
        },
      },
    );
    if (response is! Map || response['suggestions'] is! List) {
      throw const FormatException('The server returned invalid place suggestions.');
    }

    final suggestions = <PlaceSuggestion>[];
    for (final entry in response['suggestions'] as List) {
      if (entry is! Map) continue;
      final placeId = entry['placeId'];
      final description = entry['description'];
      if (placeId is String && description is String) {
        suggestions.add(PlaceSuggestion(
          placeId: placeId,
          description: description,
        ));
      }
    }
    return suggestions;
  }

  Future<PlaceDetails> getDetails(String placeId) async {
    final response = await _api.get(
      '/places/${Uri.encodeComponent(placeId)}',
    );
    if (response is! Map || response['place'] is! Map) {
      throw const FormatException('The server returned invalid place details.');
    }

    final place = response['place'] as Map;
    final latitude = place['latitude'];
    final longitude = place['longitude'];
    if (latitude is! num ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude is! num ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('The selected place has no valid map location.');
    }
    return PlaceDetails(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      label: place['label'] is String ? place['label'] as String : '',
    );
  }
}