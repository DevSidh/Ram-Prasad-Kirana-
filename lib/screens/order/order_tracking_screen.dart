import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
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

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshOrder(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOrder();
  }

  Future<void> _refreshOrder() async {
    try {
      await context.read<OrderProvider>().refreshOrder(widget.order.id);
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

  void _fitMapToMarkers(LatLng destination, {LatLng? riderLocation}) {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    final points = [
      _storeLocation,
      destination,
      if (riderLocation != null) riderLocation,
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
      controller.animateCamera(
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
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude),
        ),
        44,
      ),
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
        order.address.latitude != null && order.address.longitude != null;
    final destination = hasDestination
        ? LatLng(
            order.address.latitude!,
            order.address.longitude!,
          )
        : null;
    final riderLocation = order.deliveryPersonLatitude != null &&
            order.deliveryPersonLongitude != null
        ? LatLng(
            order.deliveryPersonLatitude!,
            order.deliveryPersonLongitude!,
          )
        : null;

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
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: 'Delivery rider · live location',
                                  ),
                                ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
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
                            icon: Icons.route_rounded,
                            label: riderLocation == null
                                ? 'Store to delivery address'
                                : 'Delivery rider · live',
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
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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

    return _TrackingCard(
      theme: theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDelivered ? Icons.task_alt_rounded : Icons.schedule_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: theme.textTheme.labelLarge),
                const SizedBox(height: 5),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
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
                      '×${item.quantity}',
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
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );
}
