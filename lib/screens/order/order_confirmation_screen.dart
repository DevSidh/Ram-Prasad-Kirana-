import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../navigation/main_bottom_nav.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/store_animation.dart';
import 'order_tracking_screen.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final Order order;

  const OrderConfirmationScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const StoreAnimation(
                assetPath: 'animations/order_success.lottie',
                size: 130,
                semanticLabel: 'Order successfully placed',
                loop: false,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Congratulations!'),
                style: const TextStyle(
                  color: AppConstants.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order placed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${order.orderNumber} has been sent to the store. The store will confirm preparation and delivery timing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order total',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${order.total.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment method',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          order.paymentMethod == 'COD'
                              ? 'Cash on Delivery'
                              : order.paymentMethod,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConstants.borderLight),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < order.items.length; index++)
                        _OrderItemRow(
                          item: order.items[index],
                          showDivider: index < order.items.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(order: order),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.radar,
                    color: AppConstants.primaryForeground,
                  ),
                  label: const Text(
                    'Track order',
                    style: TextStyle(
                      color: AppConstants.primaryForeground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainBottomNav(),
                      ),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue shopping'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final CartItem item;
  final bool showDivider;

  const _OrderItemRow({
    required this.item,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            ProductThumbnail(
              imageUrl: item.product.imageUrl,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${item.product.name} × ${item.quantity}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppConstants.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${AppConstants.currencySymbol}${item.totalPrice.toInt()}',
              style: TextStyle(
                color: AppConstants.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (showDivider) const Divider(height: 16),
      ],
    );
  }
}
