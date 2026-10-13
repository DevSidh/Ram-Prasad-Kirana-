import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/order_provider.dart';

class DeliveryHomeScreen extends StatelessWidget {
  const DeliveryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final activeDeliveries = orderProvider.orders.where((o) => o.status != 'DELIVERED' && o.status != 'CANCELLED').toList();

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Courier Dispatch Console'),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Courier Profile Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppConstants.primary,
                    radius: 24,
                    child: Text('RS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ramesh Shrestha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Electric Scooter #BA-2-PA-4481 · 4.9★', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ON DUTY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Active Delivery Tasks (${activeDeliveries.length})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textDark),
            ),
            const SizedBox(height: 12),

            if (activeDeliveries.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('No pending deliveries assigned.', style: TextStyle(color: AppConstants.textMuted)),
                ),
              )
            else
              ...activeDeliveries.map((ord) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConstants.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Task #${ord.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(ord.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppConstants.primary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Drop-off: ${ord.address.street}, ${ord.address.city}', style: const TextStyle(fontSize: 12)),
                      Text('Customer: ${ord.address.fullName} (${ord.address.phone})', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Collect on Doorstep:', style: TextStyle(fontSize: 11, color: AppConstants.textMuted)),
                            Text(
                              ord.paymentMethod == 'COD' ? 'Rs. ${ord.total.toInt()} (CASH)' : 'Prepaid Online',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Call Customer'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                orderProvider.updateOrderStatus(ord.id, 'DELIVERED');
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                              child: const Text('Mark Delivered', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
