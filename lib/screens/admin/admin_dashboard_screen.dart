import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../widgets/store_animation.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback? onOrdersRequested;

  const AdminDashboardScreen({
    super.key,
    required this.api,
    this.onOrdersRequested,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  AdminDashboard? _dashboard;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _adminApi.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _dashboard == null) {
      return _AdminLoadError(message: _error!, onRetry: _load);
    }

    final dashboard = _dashboard!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store at a glance',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('Live figures from your store', style: TextStyle(color: AppConstants.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: _error!),
          ],
          const SizedBox(height: 20),
          const _SectionHeading(title: 'Sales', trailing: 'LIVE'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SalesCard(
                  label: 'Today',
                  value: _money(dashboard.sales['today']),
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFF047857),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SalesCard(
                  label: 'All time',
                  value: _money(dashboard.sales['total']),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Products', trailing: 'CATALOG'),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _Metric('Total', _number(dashboard.products['total']), Icons.inventory_2_outlined),
              _Metric('Active', _number(dashboard.products['active']), Icons.check_circle_outline, green: true),
              _Metric('Out of stock', _number(dashboard.products['outOfStock']), Icons.remove_shopping_cart_outlined, alert: true),
              _Metric('Low stock', _number(dashboard.products['lowStock']), Icons.warning_amber_rounded, alert: true),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Orders', trailing: 'ALL STATUSES'),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _Metric('Total', _number(dashboard.orders['total']), Icons.receipt_long_outlined),
              _Metric('Pending', _number(dashboard.orders['pending']), Icons.hourglass_empty_rounded),
              _Metric('Processing', _number(dashboard.orders['processing']), Icons.sync_rounded),
              _Metric('Out for delivery', _number(dashboard.orders['outForDelivery']), Icons.delivery_dining_outlined),
              _Metric('Delivered', _number(dashboard.orders['delivered']), Icons.task_alt_rounded, green: true),
              _Metric('Cancelled', _number(dashboard.orders['cancelled']), Icons.cancel_outlined, alert: true),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Customers', trailing: 'REGISTERED'),
          const SizedBox(height: 10),
          _SalesCard(
            label: 'Total customers',
            value: _number(dashboard.customers['total']),
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: _SectionHeading(title: 'Recent orders', trailing: 'LATEST'),
              ),
              TextButton(
                onPressed: widget.onOrdersRequested,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (dashboard.recentOrders.isEmpty)
            const _EmptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'No recent orders',
              message: 'Orders will appear here when customers place them.',
            )
          else
            ...dashboard.recentOrders.map(
              (order) => _RecentOrderTile(
                order,
                onTap: widget.onOrdersRequested,
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final bool green;
  final bool alert;

  const _Metric(this.label, this.value, this.icon, {this.green = false, this.alert = false});
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> items;

  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = item.alert
                ? const Color(0xFFB45309)
                : item.green
                    ? const Color(0xFF047857)
                    : AppConstants.primary;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 17, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppConstants.textMuted),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SalesCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SalesCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppConstants.textMuted)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;

  const _RecentOrderTile(this.order, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final orderId = order['orderNumber']?.toString() ?? order['id']?.toString() ?? 'Order';
    final status = order['status']?.toString() ?? '—';
    final total = order['total'];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppConstants.primaryLight,
            child: const Icon(Icons.receipt_long_outlined, color: AppConstants.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderId, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(status.replaceAll('_', ' '), style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (total != null)
            Text(_money(total), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionHeading({required this.title, this.trailing = ''});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        if (trailing.isNotEmpty)
          Text(trailing, style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppConstants.textMuted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AdminLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _ErrorContent(message: message, onRetry: onRetry),
        ),
      );
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message, style: const TextStyle(color: Color(0xFF9A3412))),
        ),
      );
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorContent({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'Dashboard unavailable',
        message: message,
        retryLabel: 'Try again',
        onRetry: onRetry,
      );
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyPanel({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(        color: AppConstants.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppConstants.borderLight)),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppConstants.textMuted),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
          ],
        ),
      );
}

String _number(dynamic value) => value?.toString() ?? '—';

String _money(dynamic value) {
  final amount = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (amount == null) return '—';
  return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');
