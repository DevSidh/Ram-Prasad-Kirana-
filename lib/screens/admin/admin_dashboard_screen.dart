import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
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
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
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
                  color: AppColors.successText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SalesCard(
                  label: 'All time',
                  value: _money(dashboard.sales['total']),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.warningText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Products', trailing: 'CATALOG'),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _Metric('Total', _number(dashboard.products['total']),
                  Icons.inventory_2_outlined),
              _Metric('Active', _number(dashboard.products['active']),
                  Icons.check_circle_outline,
                  green: true),
              _Metric('Out of stock', _number(dashboard.products['outOfStock']),
                  Icons.remove_shopping_cart_outlined,
                  alert: true),
              _Metric('Low stock', _number(dashboard.products['lowStock']),
                  Icons.warning_amber_rounded,
                  alert: true),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Orders', trailing: 'ALL STATUSES'),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _Metric('Total', _number(dashboard.orders['total']),
                  Icons.receipt_long_outlined),
              _Metric('Pending', _number(dashboard.orders['pending']),
                  Icons.hourglass_empty_rounded),
              _Metric('Processing', _number(dashboard.orders['processing']),
                  Icons.sync_rounded),
              _Metric(
                  'Out for delivery',
                  _number(dashboard.orders['outForDelivery']),
                  Icons.delivery_dining_outlined),
              _Metric('Delivered', _number(dashboard.orders['delivered']),
                  Icons.task_alt_rounded,
                  green: true),
              _Metric('Cancelled', _number(dashboard.orders['cancelled']),
                  Icons.cancel_outlined,
                  alert: true),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Customers', trailing: 'REGISTERED'),
          const SizedBox(height: 10),
          _SalesCard(
            label: 'Total customers',
            value: _number(dashboard.customers['total']),
            icon: Icons.people_outline_rounded,
            color: AppColors.muted,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child:
                    _SectionHeading(title: 'Recent orders', trailing: 'LATEST'),
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

  const _Metric(this.label, this.value, this.icon,
      {this.green = false, this.alert = false});
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
            return AppStatCard(
              label: item.label,
              value: item.value,
              icon: item.icon,
              tint: item.alert
                  ? AppColors.thumbnailAmber
                  : item.green
                      ? AppColors.thumbnailGreen
                      : AppColors.thumbnailBlue,
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
    return AppStatCard(
      label: label,
      value: value,
      icon: icon,
      tint: color == AppColors.successText
          ? AppColors.thumbnailGreen
          : color == AppColors.warningText
              ? AppColors.thumbnailAmber
              : AppColors.thumbnailLavender,
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;

  const _RecentOrderTile(this.order, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final orderId =
        order['orderNumber']?.toString() ?? order['id']?.toString() ?? 'Order';
    final status = order['status']?.toString() ?? '—';
    final total = order['total'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppRowCard(
        title: orderId,
        subtitle: status.replaceAll('_', ' '),
        leading: const Icon(Icons.receipt_long_outlined, size: 21),
        tint: AppColors.thumbnailBlue,
        onTap: onTap,
        trailing: total == null ? null : Text(_money(total)),
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
        Expanded(child: AppSectionLabel(title)),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.72,
                ),
          ),
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
        decoration: BoxDecoration(
            color: AppColors.warningPill,
            borderRadius: BorderRadius.circular(AppRadii.input)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message, style: TextStyle(color: AppColors.warningText)),
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

  const _EmptyPanel(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              offset: const Offset(0, 6),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.muted),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
