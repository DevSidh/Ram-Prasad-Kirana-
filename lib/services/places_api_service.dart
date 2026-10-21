import 'package:uuid/uuid.dart';

import 'api_service.dart';

class PlaceSuggestion {
  final String placeId;
  final String label;
  final String primaryText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.label,
    required this.primaryText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final placeId = json['placeId'];
    final label = json['label'];
    if (placeId is! String || label is! String) {
      throw const FormatException('The place search returned an invalid result.');
    }
    return PlaceSuggestion(
      placeId: placeId,
      label: label,
      primaryText: json['primaryText'] as String? ?? label,
      secondaryText: json['secondaryText'] as String? ?? '',
    );
  }
}

class PlaceDetails {
  final String label;
  final String street;
  final String city;
  final String province;
  final double latitude;
  final double longitude;

  const PlaceDetails({
    required this.label,
    required this.street,
    required this.city,
    required this.province,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('The place search returned invalid coordinates.');
    }
    return PlaceDetails(
      label: json['label'] as String? ?? '',
      street: json['street'] as String? ?? '',
      city: json['city'] as String? ?? '',
      province: json['province'] as String? ?? '',
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}

class PlacesApiService {
  final ApiService _api;
  final Uuid _uuid;

  PlacesApiService(this._api, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  String createSessionToken() => _uuid.v4();

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    required String sessionToken,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _api.post('/places/autocomplete', {
      'input': input,
      'sessionToken': sessionToken,
      'locationBias': {'latitude': latitude, 'longitude': longitude},
    });
    if (response is! Map<String, dynamic> || response['suggestions'] is! List) {
      throw const FormatException('The place search returned invalid suggestions.');
    }
    return (response['suggestions'] as List)
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestion.fromJson)
        .toList(growable: false);
  }

  Future<PlaceDetails> getDetails(
    String placeId, {
    required String sessionToken,
  }) async {
    final response = await _api.post('/places/details', {
      'placeId': placeId,
      'sessionToken': sessionToken,
    });
    if (response is! Map<String, dynamic>) {
      throw const FormatException('The place search returned invalid details.');
    }
    return PlaceDetails.fromJson(response);
  }
}
