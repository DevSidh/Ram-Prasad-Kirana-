import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/places_api_service.dart';

const _googleMapsConfigured =
    bool.fromEnvironment('GOOGLE_MAPS_CONFIGURED', defaultValue: true);

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
  static const _defaultPosition = LatLng(26.743218, 85.918854);
  final TextEditingController _searchController = TextEditingController();
  late PlacesApiService _places;
  bool _placesInitialized = false;
  Timer? _suggestionTimer;
  List<PlaceSuggestion> _suggestions = [];
  late LatLng _selectedPosition;
  LatLng? _currentDevicePosition;
  double? _currentDeviceAccuracy;
  GoogleMapController? _mapController;
  bool _resolvingAddress = false;
  bool _searchingLocation = false;
  bool _gettingCurrentLocation = false;
  bool _showDeviceLocation = false;
  bool _loadingSuggestions = false;
  int _suggestionRevision = 0;
  String? _placesSessionToken;
  String? _selectedPlaceLabel;
  PlaceDetails? _selectedPlaceDetails;

  @override
  void initState() {
    super.initState();
    _selectedPosition =
        widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : _defaultPosition;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_placesInitialized) {
      _places = PlacesApiService(context.read<ApiService>());
      _placesInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  void _scheduleSuggestions(String value) {
    _suggestionTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _placesSessionToken = null;
      setState(() {
        _suggestions = [];
        _loadingSuggestions = false;
      });
      return;
    }

    _placesSessionToken ??= _places.createSessionToken();
    setState(() {
      _suggestions = [];
      _loadingSuggestions = query.length >= 3;
    });
    if (query.length >= 3) {
      _suggestionTimer = Timer(const Duration(milliseconds: 250), () {
        _loadSuggestions(query);
      });
    }
  }

  Future<void> _loadSuggestions(String query) async {
    final revision = ++_suggestionRevision;
    if (mounted) setState(() => _loadingSuggestions = true);
    try {
      final results = await _places.autocomplete(
        query,
        sessionToken: _placesSessionToken!,
        latitude: _selectedPosition.latitude,
        longitude: _selectedPosition.longitude,
      );
      if (!mounted ||
          revision != _suggestionRevision ||
          _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Location suggestions failed: $error\n$stackTrace');
      if (mounted && revision == _suggestionRevision) {
        setState(() {
          _suggestions = [];
          _loadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    if (_searchingLocation || _resolvingAddress) return;
    setState(() {
      _searchingLocation = true;
      _suggestions = [];
    });
    try {
      final details = await _places.getDetails(
        suggestion.placeId,
        sessionToken: _placesSessionToken ?? _places.createSessionToken(),
      );
      if (!mounted) return;
      final position = LatLng(details.latitude, details.longitude);
      await _moveToPosition(position, zoom: 17);
      if (!mounted) return;
      _searchController.text =
          details.label.isEmpty ? suggestion.label : details.label;
      setState(() {
        _selectedPosition = position;
        _selectedPlaceLabel = _searchController.text;
        _selectedPlaceDetails = details;
        _placesSessionToken = null;
      });
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  Future<void> _searchLocation() async {
    if (_searchingLocation || _resolvingAddress) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showMessage(context.tr('Enter a place, street, or area to search.'));
      return;
    }
    if (query.length < 3) {
      _showMessage(context.tr('Enter at least three characters to search.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchingLocation = true);
    try {
      final sessionToken = _placesSessionToken ?? _places.createSessionToken();
      final suggestions = await _places.autocomplete(
        query,
        sessionToken: sessionToken,
        latitude: _selectedPosition.latitude,
        longitude: _selectedPosition.longitude,
      );
      if (!mounted) return;
      if (suggestions.isEmpty) {
        _showMessage(
          context.tr('No matching places found. Try a nearby landmark.'),
        );
        return;
      }
      _placesSessionToken = sessionToken;
      if (mounted) setState(() => _searchingLocation = false);
      await _selectSuggestion(suggestions.first);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingCurrentLocation || _resolvingAddress) return;
    setState(() => _gettingCurrentLocation = true);
    try {
      final location = await LocationService().getCurrentCoordinates();
      if (!mounted) return;
      final position = LatLng(location.latitude, location.longitude);
      await _moveToPosition(position, zoom: 17);
      if (!mounted) return;
      setState(() {
        _selectedPosition = position;
        _currentDevicePosition = position;
        _currentDeviceAccuracy = location.accuracyMeters;
        _showDeviceLocation = true;
        _selectedPlaceLabel = 'Current location';
        _selectedPlaceDetails = null;
      });
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _gettingCurrentLocation = false);
    }
  }

  Future<void> _moveToPosition(LatLng position, {required double zoom}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
  }

  void _setSelectedPosition(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _selectedPlaceLabel = null;
      _selectedPlaceDetails = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLocation() async {
    setState(() => _resolvingAddress = true);
    var street = _selectedPlaceDetails?.street ?? '';
    var city = _selectedPlaceDetails?.city ?? '';
    var province = _selectedPlaceDetails?.province ?? '';

    if (street.isEmpty || city.isEmpty || province.isEmpty) {
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          _selectedPosition.latitude,
          _selectedPosition.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          street = street.isNotEmpty
              ? street
              : [
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
          city = city.isNotEmpty
              ? city
              : _firstPlaceName([
                  place.locality,
                  place.subAdministrativeArea,
                  place.administrativeArea,
                ]);
          province = province.isNotEmpty
              ? province
              : _firstPlaceName([
                  place.administrativeArea,
                  place.subAdministrativeArea,
                ]);
        }
      } catch (_) {
        if (!mounted) return;
        _showMessage(
          'Pin saved, but address details could not be found. Fill them in manually.',
        );
      }
    }

    if (!mounted) return;
    setState(() => _resolvingAddress = false);
    final isOutsideJanakpur =
        city.isNotEmpty && !city.toLowerCase().contains('janakpur');
    if (isOutsideJanakpur) {
      final useLocation = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('Check delivery area')),
          content: Text(context.tr(
            'This location appears to be outside our Janakpur delivery area.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Review location')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Use anyway')),
            ),
          ],
        ),
      );
      if (useLocation != true || !mounted) return;
    }
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
    context.watch<ThemeProvider?>();
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
                    Text(
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
                  onMapCreated: (controller) => _mapController = controller,
                  markers: {
                    Marker(
                      markerId: const MarkerId('delivery-location'),
                      position: _selectedPosition,
                      draggable: true,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: InfoWindow(
                        title: _selectedPlaceLabel ?? 'Delivery location',
                        snippet: 'Drag the pin to fine-tune this spot',
                      ),
                      onDragEnd: _setSelectedPosition,
                    ),
                  },
                  circles: _currentDevicePosition == null
                      ? const {}
                      : {
                          Circle(
                            circleId:
                                const CircleId('current-location-accuracy'),
                            center: _currentDevicePosition!,
                            radius: (_currentDeviceAccuracy ?? 30)
                                .clamp(10, 2000)
                                .toDouble(),
                            fillColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.14),
                            strokeColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.48),
                            strokeWidth: 1,
                          ),
                        },
                  onTap: _setSelectedPosition,
                  myLocationEnabled: _showDeviceLocation,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapType: MapType.normal,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: _scheduleSuggestions,
                        onSubmitted: (_) => _searchLocation(),
                        decoration: InputDecoration(
                          hintText: context.tr('Search a place or address'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchingLocation
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Search location',
                                  onPressed: _searchLocation,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.trim().isNotEmpty ||
                    _suggestions.isNotEmpty ||
                    _loadingSuggestions)
                  Positioned(
                    top: 76,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 5,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length + 1,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final query = _searchController.text.trim();
                                return ListTile(
                                  dense: true,
                                  leading: _searchingLocation
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.search_rounded,
                                          color: AppConstants.primary,
                                        ),
                                  title: Text(
                                    'Search "$query"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: _loadingSuggestions
                                      ? const Text(
                                          'Finding nearby suggestions…')
                                      : null,
                                  onTap: _searchLocation,
                                );
                              }
                              final place = _suggestions[index - 1];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppConstants.primary,
                                ),
                                title: Text(
                                  place.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSuggestion(place),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 96,
                  child: SafeArea(
                    top: false,
                    child: FloatingActionButton.small(
                      heroTag: 'map-current-location',
                      tooltip: 'Use my current location',
                      onPressed:
                          _gettingCurrentLocation ? null : _useCurrentLocation,
                      child: _gettingCurrentLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 76,
                  bottom: 78,
                  child: SafeArea(
                    top: false,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Text(
                              _selectedPlaceLabel ??
                                  'Tap the map or drag the pin to adjust',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
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
