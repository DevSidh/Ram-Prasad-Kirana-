import '../../widgets/billing_localized_widgets.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/offline_pos_store.dart';
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
    this.offlineStore = const OfflinePosStore(),
  });
  final OfflinePosStore offlineStore;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  AdminDashboard? _dashboard;
  String? _error;
  bool _loading = true;
  double _offlineSalesTotal = 0;
  bool _observedTabVisibility = false;
  bool _wasTabVisible = true;
  int _requestId = 0;
  DateTime? _filterDay;

  String? get _dayKey => _filterDay == null
      ? null
      : '${_filterDay!.year}-${_filterDay!.month.toString().padLeft(2, '0')}-${_filterDay!.day.toString().padLeft(2, '0')}';

  Future<void> _chooseDay() async {
    final nepalNow =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
    final day = await showDatePicker(
        context: context,
        initialDate:
            _filterDay ?? DateTime(nepalNow.year, nepalNow.month, nepalNow.day),
        firstDate: DateTime(2020),
        lastDate: DateTime(nepalNow.year + 1, 12, 31));
    if (day == null || !mounted) return;
    setState(() {
      _filterDay = day;
      _dashboard = null;
    });
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_observedTabVisibility && isVisible && !_wasTabVisible) {
      _load();
    }
    _observedTabVisibility = true;
    _wasTabVisible = isVisible;
  }

  Future<void> _load() async {
    final request = ++_requestId;
    final day = _dayKey;
    final offlineStore = widget.offlineStore;
    final loadingDeadline = Timer(const Duration(seconds: 4), () {
      if (mounted && request == _requestId && _loading) {
        setState(() {
          _dashboard ??= AdminDashboard.fromJson(const {});
          _loading = false;
          _error =
              'Still refreshing online totals. You can use the menus while the connection recovers.';
        });
      }
    });
    setState(() {
      _loading = _dashboard == null;
      _error = null;
    });
    // Start the server request immediately instead of waiting for every local
    // invoice to be read. Capture failures until the cached view is ready.
    final server = _adminApi
        .getDashboard(day: day)
        .then<Object>((value) => value, onError: (Object error) => error);
    double offlineSales = 0;
    Map<String, dynamic>? snapshot;
    String? localError;
    final localTotals = day == null
        ? offlineStore.readOfflineSalesTotal()
        : offlineStore.readOfflineSalesTotalForDay(day);
    unawaited(localTotals.then<void>((value) {
      offlineSales = value;
      if (mounted && request == _requestId) {
        setState(() => _offlineSalesTotal = value);
      }
    }, onError: (Object error) {
      localError =
          'Local bill totals could not be loaded. Check local storage and retry.';
      if (mounted && request == _requestId) setState(() => _error = localError);
    }));
    try {
      // The snapshot is small; show it before scanning the local bill ledger.
      snapshot = await offlineStore
          .readDashboardSnapshot()
          .timeout(const Duration(seconds: 1));
      final cached = snapshot?['filterDay'] == day ? snapshot : null;
      if (cached != null && mounted && request == _requestId) {
        setState(() {
          _dashboard = AdminDashboard.fromJson(cached);
          _loading = false;
        });
      }
    } catch (_) {
      localError =
          'The saved dashboard could not be loaded. Live totals are still refreshing.';
    }
    final cachedSnapshot = snapshot?['filterDay'] == day ? snapshot : null;
    if (!mounted || request != _requestId) return;
    if (mounted) {
      setState(() {
        _offlineSalesTotal = offlineSales;
        if (_dashboard == null && cachedSnapshot != null) {
          _dashboard = AdminDashboard.fromJson(cachedSnapshot);
        }
        _loading = _dashboard == null && loadingDeadline.isActive;
      });
    }
    try {
      final response = await server;
      if (response is! AdminDashboard) throw response;
      final result = response;
      if (!mounted || request != _requestId) return;
      setState(() {
        _dashboard = result;
        _offlineSalesTotal = offlineSales;
        _error = localError;
        _loading = false;
      });
      try {
        await offlineStore
            .saveDashboardSnapshot({...result.toJson(), 'filterDay': day});
      } catch (_) {
        if (mounted && request == _requestId) {
          setState(() => _error =
              'Live totals loaded, but their local snapshot could not be saved.');
        }
      }
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _dashboard ??= AdminDashboard.fromJson(const {});
        final serverError = cachedSnapshot == null
            ? 'Offline mode: online sales are unavailable until this computer reconnects. Offline bills are still included below.'
            : 'Showing the last saved online totals. Reconnect to refresh them.';
        _error = [serverError, if (localError != null) localError].join('\n');
        _loading = false;
      });
    } finally {
      loadingDeadline.cancel();
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  onPressed: _chooseDay,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: BillingText(_dayKey ?? 'All dates')),
              if (_filterDay != null)
                TextButton(
                    onPressed: () {
                      setState(() {
                        _filterDay = null;
                        _dashboard = null;
                      });
                      _load();
                    },
                    child: const BillingText('Clear date filter')),
              const BillingText('Date applies to sales and orders'),
              BillingIconButton(
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
          const _SectionHeading(title: 'Sales', trailing: 'ONLINE + OFFLINE'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SalesCard(
                  label: 'Online sales',
                  value: _money(dashboard.sales['total']),
                  icon: Icons.cloud_outlined,
                  color: AppColors.successText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SalesCard(
                  label: 'Offline sales',
                  value: _money(_offlineSalesTotal),
                  icon: Icons.computer_outlined,
                  color: AppColors.warningText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SalesCard(
            label: 'Total sales',
            value:
                _totalSalesLabel(dashboard.sales['total'], _offlineSalesTotal),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.successText,
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Products', trailing: 'CATALOG'),
          const BillingText('Retails, wholesale and drinks'),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _Metric('Total products', _number(dashboard.products['total']),
                  Icons.inventory_2_outlined),
              if (dashboard.products.containsKey('retail'))
                _Metric('Retails', _number(dashboard.products['retail']),
                    Icons.storefront_outlined),
              if (dashboard.products.containsKey('wholesale'))
                _Metric('Wholesale', _number(dashboard.products['wholesale']),
                    Icons.inventory_outlined),
              if (dashboard.products.containsKey('drinks'))
                _Metric('Drinks', _number(dashboard.products['drinks']),
                    Icons.local_drink_outlined),
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
                child: const BillingText('View all'),
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
        final columns = constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 420
                ? 2
                : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 170,
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
        trailing: total == null ? null : BillingText(_money(total)),
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
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        AppSectionLabel(title),
        if (trailing.isNotEmpty)
          BillingText(
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
          child: BillingText(message,
              style: TextStyle(color: AppColors.warningText)),
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
            BillingText(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            BillingText(
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

String _totalSalesLabel(dynamic onlineSales, double offlineSales) {
  final onlineAmount = onlineSales is num
      ? onlineSales.toDouble()
      : double.tryParse(onlineSales?.toString() ?? '');
  if (onlineAmount == null) return 'â€”';
  return _money(onlineAmount + offlineSales);
}
