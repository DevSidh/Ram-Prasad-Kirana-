import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants.dart';

const _googleMapsConfigured =
    bool.fromEnvironment('GOOGLE_MAPS_CONFIGURED', defaultValue: !kIsWeb);

class PickedAddressLocation {
  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String province;

  const PickedAddressLocation({
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.city,
    required this.province,
  });
}

class AddressMapPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const AddressMapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AddressMapPicker> createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends State<AddressMapPicker> {
  static const _defaultPosition = LatLng(26.7288, 85.9263);
  late LatLng _selectedPosition;
  bool _resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition =
        widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : _defaultPosition;
  }

  Future<void> _confirmLocation() async {
    setState(() => _resolvingAddress = true);
    var street = '';
    var city = '';
    var province = '';

    try {
      final places = await Geocoding().placemarkFromCoordinates(
        _selectedPosition.latitude,
        _selectedPosition.longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        street = [
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
        city = _firstPlaceName([
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        province = _firstPlaceName([
          place.administrativeArea,
          place.subAdministrativeArea,
        ]);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pin saved. Fill in any address details that were not found.',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _resolvingAddress = false);
    Navigator.pop(
      context,
      PickedAddressLocation(
        latitude: _selectedPosition.latitude,
        longitude: _selectedPosition.longitude,
        street: street,
        city: city,
        province: province,
      ),
    );
  }

  String _firstPlaceName(List<String?> candidates) {
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose location'),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: !_googleMapsConfigured
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: AppConstants.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Map pin is unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can still save your delivery address by entering the details manually. A Google Maps key is only needed for the optional map pin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppConstants.textMuted),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Enter address manually'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('delivery-location'),
                      position: _selectedPosition,
                      infoWindow: const InfoWindow(title: 'Delivery location'),
                    ),
                  },
                  onTap: (position) =>
                      setState(() => _selectedPosition = position),
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Tap the map to place your delivery pin',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: FilledButton.icon(
                      onPressed: _resolvingAddress ? null : _confirmLocation,
                      icon: _resolvingAddress
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.place_outlined),
                      label: Text(
                        _resolvingAddress
                            ? 'Finding address...'
                            : 'Use this location',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
