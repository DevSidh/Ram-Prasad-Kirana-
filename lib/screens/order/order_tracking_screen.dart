import 'dart:async';
import 'dart:ui' as ui;

import 'package:geolocator/geolocator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show Factory, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/order.dart';
import '../../providers/language_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/customer_location_consent.dart';
import '../../services/location_service.dart';

const LatLng _storeLocation = LatLng(26.743218, 85.918854);
const Duration _nepalUtcOffset = Duration(hours: 5, minutes: 45);

String _addressLabel(Order order) {
  final address = order.address;
  return [
    address.street,
    address.landmark,
    address.city,
    address.province,
  ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
}

bool _isValidCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude.isFinite &&
    longitude >= -180 &&
    longitude <= 180;

List<LatLng> _decodeEncodedPolyline(String encoded) {
  if (encoded.isEmpty || encoded.length > 100000) {
    throw const FormatException('The route line is invalid.');
  }
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  final points = <LatLng>[];

  int readDelta() {
    var result = 0;
    var shift = 0;
    var value = 0;
    do {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('The route line is invalid.');
      }
      value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('The route line is invalid.');
      }
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20);
    return result & 1 != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    latitude += readDelta();
    longitude += readDelta();
    final point = LatLng(latitude / 1e5, longitude / 1e5);
    if (!_isValidCoordinate(point.latitude, point.longitude)) {
      throw const FormatException('The route line contains an invalid point.');
    }
    points.add(point);
    if (points.length > 20000) {
      throw const FormatException('The route line is too detailed.');
    }
  }
  if (points.length < 2) {
    throw const FormatException('The route line is incomplete.');
  }
  return points;
}

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  StreamSubscription<Position>? _customerLocationSubscription;
  GoogleMapController? _mapController;
  BitmapDescriptor? _riderMarkerIcon;
  DateTime? _lastRouteRequestedAt;
  String? _refreshError;
  String? _routeError;
  String _routeOrigin = 'store';
  List<LatLng> _routePoints = const [];
  LatLng? _deviceLocation;
  LatLng? _lastFollowedRiderLocation;
  bool _isAppForeground = true;
  bool _isRouteVisible = true;
  bool _isProgrammaticCameraMove = false;
  bool _followRider = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadRiderMarkerIcon());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshOrder());
      final address = widget.order.address;
      if (_isValidCoordinate(address.latitude, address.longitude) && !kIsWeb) {
        unawaited(_loadRoadRoute());
      }
    });
    _startRefreshTimer();
  }

  Future<void> _loadRiderMarkerIcon() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const logicalSize = Size(96, 124);
      canvas.scale(2);
      const painter = _DeliveryBikePinPainter();
      painter.paint(canvas, logicalSize);
      final picture = recorder.endRecording();
      final image = await picture.toImage(192, 248);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        throw StateError('Could not encode the delivery rider map marker.');
      }
      final descriptor = BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        width: 48,
        height: 62,
      );
      if (mounted) setState(() => _riderMarkerIcon = descriptor);
    } catch (error, stackTrace) {
      debugPrint(
          'Could not create the delivery rider map marker: $error\n$stackTrace');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_isRouteVisible == isVisible) return;
    _isRouteVisible = isVisible;
    if (isVisible && _isAppForeground) {
      _startRefreshTimer();
      unawaited(_refreshOrder());
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    unawaited(_customerLocationSubscription?.cancel());
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    if (_isAppForeground) {
      _startRefreshTimer();
      unawaited(_refreshOrder());
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _startRefreshTimer() {
    if (!_isAppForeground || !_isRouteVisible || _refreshTimer != null) return;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshOrder()),
    );
  }

  Future<void> _refreshOrder() async {
    if (!_isAppForeground || !_isRouteVisible || !mounted) return;
    try {
      await context.read<OrderProvider>().refreshOrder(widget.order.id);
      await _syncCustomerLocationSharing();
      final order = _latestOrder;
      final address = order.address;
      final lastRouteRequest = _lastRouteRequestedAt;
      if (!kIsWeb &&
          order.status == 'OUT_FOR_DELIVERY' &&
          _isValidCoordinate(address.latitude, address.longitude) &&
          (lastRouteRequest == null ||
              DateTime.now().difference(lastRouteRequest) >=
                  const Duration(minutes: 1))) {
        unawaited(_loadRoadRoute());
      }
      if (mounted && _refreshError != null) {
        setState(() => _refreshError = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _refreshError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _syncCustomerLocationSharing() async {
    final order = _latestOrder;
    final userId = context.read<AuthProvider>().currentUser?.id;
    final isActive = order.status == 'OUT_FOR_DELIVERY';
    final api = context.read<ApiService>();
    if (!isActive || userId == null) {
      await _customerLocationSubscription?.cancel();
      _customerLocationSubscription = null;
      return;
    }
    final isEnabled = await CustomerLocationConsent.isEnabled(userId);
    if (!mounted) return;
    if (!isEnabled) {
      await _customerLocationSubscription?.cancel();
      _customerLocationSubscription = null;
      return;
    }
    if (_customerLocationSubscription != null) return;

    final locationService = LocationService();
    _customerLocationSubscription =
        locationService.backgroundPositionStream().listen(
      (position) {
        final location = LatLng(position.latitude, position.longitude);
        if (mounted) setState(() => _deviceLocation = location);
        unawaited(
          _publishCustomerLocation(
            api,
            order.id,
            position.latitude,
            position.longitude,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Customer delivery location stream failed: $error');
      },
    );

    try {
      final position = await locationService.getCurrentCoordinates();
      if (!mounted) return;
      setState(
        () => _deviceLocation = LatLng(position.latitude, position.longitude),
      );
      await _publishCustomerLocation(
        api,
        order.id,
        position.latitude,
        position.longitude,
      );
    } catch (error) {
      debugPrint('Could not get initial customer delivery location: $error');
    }
  }

  Future<void> _publishCustomerLocation(
    ApiService api,
    String orderId,
    double latitude,
    double longitude,
  ) async {
    try {
      await api.put(
        '/account/orders/${Uri.encodeComponent(orderId)}/live-location',
        {'latitude': latitude, 'longitude': longitude},
      );
    } catch (error) {
      debugPrint('Could not share delivery location: $error');
    }
  }

  void _fitMapToMarkers(LatLng destination, {LatLng? riderLocation}) {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    final points = [
      _storeLocation,
      destination,
      if (_deviceLocation != null) _deviceLocation!,
      if (riderLocation != null) riderLocation,
      ..._routePoints,
    ];
    if (points.length < 2) return;
    final minLatitude =
        points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b);
    final maxLatitude =
        points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b);
    final minLongitude =
        points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b);
    final maxLongitude =
        points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b);

    if (minLatitude == maxLatitude || minLongitude == maxLongitude) {
      _animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            (minLatitude + maxLatitude) / 2,
            (minLongitude + maxLongitude) / 2,
          ),
          13,
        ),
      );
      return;
    }
    _animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude),
        ),
        44,
      ),
    );
  }

  void _animateCamera(CameraUpdate update) {
    _isProgrammaticCameraMove = true;
    _mapController?.animateCamera(update);
  }

  Future<void> _loadRoadRoute() async {
    _lastRouteRequestedAt = DateTime.now();
    try {
      final response = await context.read<ApiService>().get(
            '/account/orders/${Uri.encodeComponent(widget.order.id)}/delivery-route',
          );
      if (response is! Map<String, dynamic> ||
          response['encodedPolyline'] is! String) {
        throw const FormatException('The route response is invalid.');
      }
      final routeOrigin = response['origin'];
      if (routeOrigin != null &&
          routeOrigin != 'rider' &&
          routeOrigin != 'store') {
        throw const FormatException('The route origin is invalid.');
      }
      final points = _decodeEncodedPolyline(
        response['encodedPolyline'] as String,
      );
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeOrigin = routeOrigin as String? ?? 'store';
        _routeError = null;
      });
      if (_followRider) {
        final address = _latestOrder.address;
        if (_isValidCoordinate(address.latitude, address.longitude)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_followRider) return;
            _fitMapToMarkers(
              LatLng(address.latitude!, address.longitude!),
              riderLocation: _validRiderLocation(_latestOrder),
            );
          });
        }
      }
    } catch (error) {
      debugPrint('Could not load the delivery route: $error');
      if (mounted) setState(() => _routeError = 'Road route unavailable');
    }
  }

  Future<void> _showCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService().getCurrentCoordinates();
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _deviceLocation = location);
      _animateCamera(CameraUpdate.newLatLngZoom(location, 15));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _handleCameraMoveStarted() {
    if (_isProgrammaticCameraMove || !_followRider) return;
    setState(() => _followRider = false);
  }

  LatLng? _validRiderLocation(Order order) {
    if (!_isValidCoordinate(
      order.deliveryPersonLatitude,
      order.deliveryPersonLongitude,
    )) {
      return null;
    }
    return LatLng(
      order.deliveryPersonLatitude!,
      order.deliveryPersonLongitude!,
    );
  }

  int _currentStepFor(Order order) {
    switch (order.status.toUpperCase()) {
      case 'CONFIRMED':
        return 1;
      case 'PROCESSING':
        return 2;
      case 'PACKED':
        return 3;
      case 'OUT_FOR_DELIVERY':
        return 4;
      case 'DELIVERED':
        return 5;
      default:
        return 0;
    }
  }

  String _statusLabelFor(Order order) {
    switch (order.status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Order confirmed';
      case 'PROCESSING':
        return 'Being prepared';
      case 'PACKED':
        return 'Packed and ready';
      case 'OUT_FOR_DELIVERY':
        return 'On the way to you';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Order cancelled';
      default:
        return 'Order received';
    }
  }

  Future<void> _callDeliveryPerson() async {
    final phone = _latestOrder.deliveryPersonPhone;
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    context.watch<OrderProvider>();
    final order = _latestOrder;
    final hasDestination =
        _isValidCoordinate(order.address.latitude, order.address.longitude);
    final destination = hasDestination
        ? LatLng(
            order.address.latitude!,
            order.address.longitude!,
          )
        : null;
    final riderLocation = _isValidCoordinate(
            order.deliveryPersonLatitude, order.deliveryPersonLongitude)
        ? LatLng(
            order.deliveryPersonLatitude!,
            order.deliveryPersonLongitude!,
          )
        : null;
    if (_followRider &&
        riderLocation != null &&
        riderLocation != _lastFollowedRiderLocation) {
      _lastFollowedRiderLocation = riderLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_followRider) return;
        _animateCamera(CameraUpdate.newLatLngZoom(riderLocation, 15));
      });
    }
    final locationUpdatedAt = order.deliveryLocationUpdatedAt;
    final locationAge = locationUpdatedAt == null
        ? null
        : DateTime.now().difference(locationUpdatedAt);
    final riderLocationIsStale = locationAge == null ||
        locationAge.isNegative ||
        locationAge > const Duration(minutes: 2);

    return Scaffold(
      backgroundColor: AppConstants.backgroundFor(
        theme.brightness == Brightness.dark,
      ),
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Order tracking'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        actions: [
          IconButton(
            tooltip: 'Refresh order',
            onPressed: _refreshOrder,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppBackground(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 310,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(26),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (destination != null && !kIsWeb)
                          GoogleMap(
                            key: const ValueKey('order-tracking-google-map'),
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                (_storeLocation.latitude +
                                        destination.latitude +
                                        (riderLocation?.latitude ?? 0)) /
                                    (riderLocation == null ? 2 : 3),
                                (_storeLocation.longitude +
                                        destination.longitude +
                                        (riderLocation?.longitude ?? 0)) /
                                    (riderLocation == null ? 2 : 3),
                              ),
                              zoom: 12,
                            ),
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _fitMapToMarkers(
                                destination,
                                riderLocation: riderLocation,
                              );
                            },
                            markers: {
                              Marker(
                                markerId: const MarkerId('store'),
                                position: _storeLocation,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen,
                                ),
                                infoWindow: const InfoWindow(
                                  title: 'Ram Prasad General Store',
                                ),
                              ),
                              Marker(
                                markerId: const MarkerId('delivery-address'),
                                position: destination,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                                infoWindow: InfoWindow(
                                  title: _addressLabel(order),
                                ),
                              ),
                              if (riderLocation != null)
                                Marker(
                                  markerId: const MarkerId('delivery-rider'),
                                  position: riderLocation,
                                  icon: _riderMarkerIcon ??
                                      BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueGreen,
                                      ),
                                  infoWindow: const InfoWindow(
                                    title: 'Delivery rider · live location',
                                  ),
                                ),
                              if (_deviceLocation != null)
                                Marker(
                                  markerId: const MarkerId('customer-location'),
                                  position: _deviceLocation!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: 'Your current location',
                                  ),
                                ),
                            },
                            polylines: _routePoints.isEmpty
                                ? const <Polyline>{}
                                : {
                                    Polyline(
                                      polylineId:
                                          const PolylineId('delivery-route'),
                                      points: _routePoints,
                                      color: const Color(0xFF4285F4),
                                      width: 4,
                                    ),
                                  },
                            gestureRecognizers: const <Factory<
                                OneSequenceGestureRecognizer>>{
                              Factory<EagerGestureRecognizer>(
                                EagerGestureRecognizer.new,
                              ),
                            },
                            onCameraMoveStarted: _handleCameraMoveStarted,
                            onCameraIdle: () =>
                                _isProgrammaticCameraMove = false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            compassEnabled: true,
                            mapToolbarEnabled: false,
                          )
                        else
                          _NoMapPinSurface(
                            theme: theme,
                            hasDestination: destination != null,
                          ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _MapStatusPill(
                            icon: riderLocation == null
                                ? Icons.route_rounded
                                : riderLocationIsStale
                                    ? Icons.location_off_rounded
                                    : Icons.delivery_dining_rounded,
                            label: riderLocation != null
                                ? [
                                    riderLocationIsStale
                                        ? 'Rider location may be outdated'
                                        : 'Rider location live',
                                    if (_routePoints.isNotEmpty)
                                      _routeOrigin == 'rider'
                                          ? 'Rider to delivery address'
                                          : 'Store to delivery address',
                                  ].join(' · ')
                                : _routePoints.isNotEmpty
                                    ? 'Road route · $_routeOrigin to delivery address'
                                    : order.status.toUpperCase() ==
                                            'OUT_FOR_DELIVERY'
                                        ? 'Waiting for rider location'
                                        : _routeError ??
                                            'Store and delivery address',
                            theme: theme,
                          ),
                        ),
                        if (destination != null && !kIsWeb)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MapControlButton(
                                  tooltip: 'Show your current location',
                                  icon: _locating
                                      ? Icons.hourglass_top_rounded
                                      : Icons.my_location_rounded,
                                  theme: theme,
                                  onPressed: _showCurrentLocation,
                                ),
                                const SizedBox(height: 8),
                                _MapControlButton(
                                  tooltip: _followRider
                                      ? 'Following live rider'
                                      : 'Follow rider and route',
                                  icon: _followRider
                                      ? Icons.gps_fixed_rounded
                                      : Icons.center_focus_strong_rounded,
                                  theme: theme,
                                  onPressed: () {
                                    setState(() => _followRider = true);
                                    if (riderLocation != null) {
                                      _lastFollowedRiderLocation =
                                          riderLocation;
                                      _animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          riderLocation,
                                          15,
                                        ),
                                      );
                                    } else {
                                      _fitMapToMarkers(
                                        destination,
                                        riderLocation: riderLocation,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (order.status.toUpperCase() == 'OUT_FOR_DELIVERY' &&
                            riderLocation == null)
                          Positioned(
                            left: 16,
                            right: 72,
                            bottom: 16,
                            child: _MapStatusPill(
                              icon: Icons.location_searching_rounded,
                              label:
                                  'Live location appears when the delivery partner shares it.',
                              theme: theme,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OrderStatusCard(
                        theme: theme,
                        status: _statusLabelFor(order),
                        orderNumber: order.orderNumber,
                        isDelivered: order.status.toUpperCase() == 'DELIVERED',
                      ),
                      const SizedBox(height: 12),
                      if (_refreshError != null) ...[
                        _RefreshErrorCard(
                            message: _refreshError!, theme: theme),
                        const SizedBox(height: 12),
                      ],
                      _DeliveryTimeCard(order: order, theme: theme),
                      if (order.deliveryPersonName != null) ...[
                        const SizedBox(height: 12),
                        _DeliveryPersonCard(
                          name: order.deliveryPersonName!,
                          phone: order.deliveryPersonPhone,
                          onCall: _callDeliveryPerson,
                          theme: theme,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ProgressCard(
                        currentStep: _currentStepFor(order),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _DestinationCard(order: order, theme: theme),
                      const SizedBox(height: 12),
                      _ItemsCard(order: order, theme: theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Order get _latestOrder {
    final provider = context.read<OrderProvider>();
    if (provider.activeOrder?.id == widget.order.id) {
      return provider.activeOrder!;
    }
    for (final order in provider.orders) {
      if (order.id == widget.order.id) return order;
    }
    return widget.order;
  }
}

class _MapControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final ThemeData theme;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.theme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          color: theme.colorScheme.onSurface,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      );
}

class _RefreshErrorCard extends StatelessWidget {
  final String message;
  final ThemeData theme;

  const _RefreshErrorCard({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) => _TrackingCard(
        theme: theme,
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Order updates are unavailable: $message',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}

class _MapStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _MapStatusPill({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppConstants.primary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _NoMapPinSurface extends StatelessWidget {
  final ThemeData theme;
  final bool hasDestination;

  const _NoMapPinSurface({
    required this.theme,
    required this.hasDestination,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_searching_rounded,
                size: 42,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                hasDestination
                    ? context.tr('Map preview unavailable')
                    : context.tr('Delivery map unavailable'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                hasDestination
                    ? context.tr(
                        'The saved address is still attached to your order. Delivery remains Rs. 40.',
                      )
                    : context.tr('This address has no saved map location.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _OrderStatusCard extends StatelessWidget {
  final ThemeData theme;
  final String status;
  final String orderNumber;
  final bool isDelivered;

  const _OrderStatusCard({
    required this.theme,
    required this.status,
    required this.orderNumber,
    required this.isDelivered,
  });

  @override
  Widget build(BuildContext context) => _TrackingCard(
        theme: theme,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isDelivered
                    ? Icons.check_rounded
                    : Icons.local_shipping_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    'Order $orderNumber',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
          ],
        ),
      );
}

class _DeliveryTimeCard extends StatelessWidget {
  final Order order;
  final ThemeData theme;

  const _DeliveryTimeCard({required this.order, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status.toUpperCase() == 'DELIVERED';
    final scheduledAt = order.scheduledDeliveryAt?.toUtc().add(_nepalUtcOffset);
    final heading = isDelivered ? 'Delivery completed' : 'Estimated delivery';
    final value = scheduledAt == null
        ? isDelivered
            ? 'Your order has been delivered.'
            : 'The store will confirm your delivery time.'
        : '${DateFormat('EEEE, d MMM · h:mm a').format(scheduledAt)} Nepal time';

    final headingStyle = isDelivered
        ? theme.textTheme.labelLarge
        : theme.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          );
    final valueStyle = isDelivered
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFB8F3D7),
          );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isDelivered ? Icons.task_alt_rounded : Icons.schedule_rounded,
          color: isDelivered
              ? theme.colorScheme.primary
              : const Color(0xFF35D39A),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: headingStyle),
              const SizedBox(height: 5),
              Text(value, style: valueStyle),
            ],
          ),
        ),
      ],
    );
    if (isDelivered) {
      return _TrackingCard(theme: theme, child: content);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF073D29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20B879)),
      ),
      child: content,
    );
  }
}

class _DeliveryPersonCard extends StatelessWidget {
  final String name;
  final String? phone;
  final VoidCallback onCall;
  final ThemeData theme;

  const _DeliveryPersonCard({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => _TrackingCard(
        theme: theme,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery partner', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 3),
                  Text(name, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (phone != null && phone!.trim().isNotEmpty)
              IconButton.filledTonal(
                tooltip: 'Call delivery partner',
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded),
              ),
          ],
        ),
      );
}

class _ProgressCard extends StatelessWidget {
  final int currentStep;
  final ThemeData theme;

  const _ProgressCard({required this.currentStep, required this.theme});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Received', Icons.receipt_long_outlined),
      ('Confirmed', Icons.check_circle_outline_rounded),
      ('Preparing', Icons.inventory_2_outlined),
      ('Packed', Icons.shopping_bag_outlined),
      ('On the way', Icons.local_shipping_outlined),
      ('Delivered', Icons.home_outlined),
    ];

    return _TrackingCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order progress', style: theme.textTheme.titleSmall),
          const SizedBox(height: 18),
          for (var index = 0; index < steps.length; index++)
            _ProgressStep(
              title: steps[index].$1,
              icon: steps[index].$2,
              isComplete: index <= currentStep,
              isLast: index == steps.length - 1,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isComplete;
  final bool isLast;
  final ThemeData theme;

  const _ProgressStep({
    required this.title,
    required this.icon,
    required this.isComplete,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: isComplete
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isComplete
                            ? theme.colorScheme.primary.withValues(alpha: 0.45)
                            : theme.dividerColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isComplete ? null : theme.disabledColor,
                fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

class _DestinationCard extends StatelessWidget {
  final Order order;
  final ThemeData theme;

  const _DestinationCard({required this.order, required this.theme});

  @override
  Widget build(BuildContext context) => _TrackingCard(
        theme: theme,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivering to', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 5),
                  Text(
                    order.address.fullName,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(_addressLabel(order), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ItemsCard extends StatelessWidget {
  final Order order;
  final ThemeData theme;

  const _ItemsCard({required this.order, required this.theme});

  @override
  Widget build(BuildContext context) => _TrackingCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In this order', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final item in order.items.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.weightGrams == null
                          ? '×${item.quantity}'
                          : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            if (order.items.length > 4)
              Text(
                '+ ${order.items.length - 4} more items',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      );
}

class _TrackingCard extends StatelessWidget {
  final ThemeData theme;
  final Widget child;

  const _TrackingCard({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );
}

class _DeliveryBikePinPainter extends CustomPainter {
  const _DeliveryBikePinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pin = Path()
      ..moveTo(48, 121)
      ..cubicTo(41, 107, 8, 74, 8, 45)
      ..cubicTo(8, 22, 26, 4, 48, 4)
      ..cubicTo(70, 4, 88, 22, 88, 45)
      ..cubicTo(88, 74, 55, 107, 48, 121)
      ..close();
    canvas.drawShadow(pin, const Color(0x88000000), 4, true);
    canvas.drawPath(pin, Paint()..color = const Color(0xFF167A4A));
    canvas.drawCircle(
      const Offset(48, 44),
      30,
      Paint()..color = Colors.white,
    );

    final bikePaint = Paint()
      ..color = const Color(0xFF173C2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(31, 52), 9, bikePaint);
    canvas.drawCircle(const Offset(65, 52), 9, bikePaint);
    final frame = Path()
      ..moveTo(31, 52)
      ..lineTo(42, 34)
      ..lineTo(50, 52)
      ..lineTo(31, 52)
      ..moveTo(42, 34)
      ..lineTo(57, 34)
      ..lineTo(65, 52)
      ..lineTo(50, 52)
      ..moveTo(57, 34)
      ..lineTo(62, 29)
      ..moveTo(39, 31)
      ..lineTo(45, 31);
    canvas.drawPath(frame, bikePaint);
    canvas.drawCircle(
      const Offset(50, 52),
      2.5,
      Paint()
        ..color = const Color(0xFF173C2B)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DeliveryBikePinPainter oldDelegate) => false;
}
