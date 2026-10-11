import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 2);
  Timer? _refreshTimer;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshOrder());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOrder();
  }

  Future<void> _refreshOrder() async {
    if (!mounted) return;
    try {
      final provider = context.read<OrderProvider>();
      await provider.refreshOrder(widget.order.id);
      final refreshedOrders =
          provider.orders.where((order) => order.id == widget.order.id);
      final refreshedOrder =
          refreshedOrders.isEmpty ? null : refreshedOrders.first;
      if (refreshedOrder?.status == 'DELIVERED' ||
          refreshedOrder?.status == 'CANCELLED') {
        _refreshTimer?.cancel();
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _getStepIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PLACED':
        return 0;
      case 'CONFIRMED':
        return 1;
      case 'PREPARING':
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

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PLACED':
        return 'Order placed';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PROCESSING':
      case 'PREPARING':
        return 'Preparing';
      case 'OUT_FOR_DELIVERY':
        return 'Out for delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final matchingOrders =
        provider.orders.where((order) => order.id == widget.order.id);
    final order = matchingOrders.isEmpty ? widget.order : matchingOrders.first;
    final currentStep = _getStepIndex(order.status);

    final steps = [
      {'title': 'Order Placed', 'time': 'Received & verified'},
      {'title': 'Confirmed', 'time': 'Store manager approved'},
      {'title': 'Preparing', 'time': 'Harvest quality inspection'},
      {'title': 'Cold Packed', 'time': 'Insulated tote bags ready'},
      {'title': 'Out for Delivery', 'time': 'Rider en route to your gate'},
      {'title': 'Delivered', 'time': 'Handed over at doorstep'},
    ];

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: Text('Track #${order.orderNumber}'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_refreshError != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Live status could not be refreshed: $_refreshError',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _refreshOrder,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delivery_dining,
                        color: AppConstants.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(order.status),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppConstants.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kathmandu Valley 45-Min Express Cold Chain',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Courier Rider Details Card
            if (order.deliveryPersonName != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppConstants.primaryLight,
                      radius: 22,
                      child: Text(
                        order.deliveryPersonName!.substring(0, 1),
                        style: const TextStyle(
                            color: AppConstants.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.deliveryPersonName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Electric Scooter · 4.9★ (1,240 deliveries)',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.phone, color: AppConstants.primary),
                      onPressed: () {},
                      tooltip: 'Call Courier',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Timeline Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Milestone Progress',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 20),
                  ...List.generate(steps.length, (index) {
                    final step = steps[index];
                    final isComplete = index <= currentStep;
                    final isLast = index == steps.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? AppConstants.primary
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isComplete
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            shape: BoxShape.circle),
                                      ),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 36,
                                color: isComplete
                                    ? AppConstants.primary
                                    : Colors.grey.shade200,
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title']!,
                                  style: TextStyle(
                                    fontWeight: isComplete
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                    color: isComplete
                                        ? AppConstants.textDark
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                Text(
                                  step['time']!,
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Destination Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Destination',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('${order.address.fullName} · ${order.address.phone}',
                      style: const TextStyle(fontSize: 12)),
                  Text('${order.address.street}, ${order.address.city}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  if (order.address.instructions != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Note: ${order.address.instructions!}',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
