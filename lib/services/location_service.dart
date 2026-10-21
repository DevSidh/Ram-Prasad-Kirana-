import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocation {
  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String province;

  const CurrentLocation({
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.city,
    required this.province,
  });
}

class CurrentCoordinates {
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  const CurrentCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });
}

class LocationService {
  Future<CurrentCoordinates> getCurrentCoordinates() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on location services to share delivery location.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Allow location access to share delivery location.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return CurrentCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  Future<CurrentLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is disabled. Enable it in your device settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final placemarks = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) {
      throw StateError('Could not find an address for your current location.');
    }

    final place = placemarks.first;
    final street = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
    ]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    final city = _firstPlaceName([
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);
    final province = _firstPlaceName([
      place.administrativeArea,
      place.subAdministrativeArea,
    ]);
    if (street.isEmpty || city.isEmpty || province.isEmpty) {
      throw StateError(
        'Could not identify your full address. Enter it manually instead.',
      );
    }

    return CurrentLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      street: street,
      city: city,
      province: province,
    );
  }

  String _firstPlaceName(List<String?> candidates) {
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
