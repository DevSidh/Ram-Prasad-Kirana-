import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../widgets/store_animation.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';

class AdminInventoryExpiryScreen extends StatefulWidget {
  final ApiService api;

  const AdminInventoryExpiryScreen({super.key, required this.api});

  @override
  State<AdminInventoryExpiryScreen> createState() =>
      _AdminInventoryExpiryScreenState();
}

class _AdminInventoryExpiryScreenState
    extends State<AdminInventoryExpiryScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  AdminInventoryExpiryPage? _result;
  List<AdminCategory> _categories = const [];
  bool _loading = true;
  bool _lowStockOnly = false;
  String _status = 'all';
  int _warningDays = 30;
  int _page = 1;
  String? _categoryId;
  String? _error;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadCategories());
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _adminApi.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoryError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _adminApi.getExpiryBatches(
        warningDays: _warningDays,
        status: _status,
        page: page,
        categoryId: _categoryId,
        lowStock: _lowStockOnly,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _changeFilter({String? status, int? warningDays, bool? lowStockOnly}) {
    setState(() {
      _status = status ?? _status;
      _warningDays = warningDays ?? _warningDays;
      _lowStockOnly = lowStockOnly ?? _lowStockOnly;
    });
    unawaited(_load());
  }

  void _changeCategory(String? categoryId) {
    setState(() => _categoryId = categoryId);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Near to Expiry')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Near to Expiry')),
        body: StorePageError(
          title: 'Expiry inventory unavailable',
          message: _error!,
          retryLabel: 'Try again',
          onRetry: _load,
        ),
      );
    }

    final result = _result!;
    final pageCount = (result.total / result.pageSize).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Near to Expiry'),
        actions: [
          IconButton(
            tooltip: 'Refresh expiry inventory',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AdminGradientBackground(
        child: RefreshIndicator(
          onRefresh: () => _load(page: _page),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 24, 30, 28),
            children: [
              Text(
                'Review dated stock and prioritize batches with the earliest expiry.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExpirySummary(
                    count: result.expiredBatches,
                    label: 'expired batches',
                    color: AppColors.errorText,
                    icon: Icons.error_outline_rounded,
                  ),
                  _ExpirySummary(
                    count: result.expiringTodayBatches,
                    label: 'expire today',
                    color: AppColors.warningText,
                    icon: Icons.today_outlined,
                  ),
                  _ExpirySummary(
                    count: result.expiringSoonBatches,
                    label: 'within ${result.warningDays} days',
                    color: AppColors.warningText,
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 155,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Show batches',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All dated')),
                        DropdownMenuItem(
                          value: 'expiring',
                          child: Text('Expiring soon'),
                        ),
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(
                            value: 'expired', child: Text('Expired')),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value != null) {
                                _changeFilter(status: value);
                              }
                            },
                    ),
                  ),
                  SizedBox(
                    width: 155,
                    child: DropdownButtonFormField<int>(
                      initialValue: _warningDays,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Warning window',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [7, 15, 30, 60]
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: Text('$days days'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value != null) {
                                _changeFilter(warningDays: value);
                              }
                            },
                    ),
                  ),
                  FilterChip(
                    label: const Text('Low stock only'),
                    selected: _lowStockOnly,
                    onSelected: _loading
                        ? null
                        : (value) => _changeFilter(lowStockOnly: value),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All categories'),
                        ),
                        ..._categories.map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) => _changeCategory(
                                value == null || value.isEmpty ? null : value,
                              ),
                    ),
                  ),
                ],
              ),
              if (_categoryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Category filters unavailable: $_categoryError',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppBanner(
                  message: _error!,
                  variant: AppStatusVariant.error,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 14),
              if (result.batches.isEmpty)
                const _ExpiryEmptyState()
              else
                ...result.batches.map(
                  (batch) => _ExpiryBatchCard(batch: batch),
                ),
              if (pageCount > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _loading || _page <= 1
                          ? null
                          : () => _load(page: _page - 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Previous'),
                    ),
                    Text('Page $_page of $pageCount'),
                    TextButton.icon(
                      onPressed: _loading || _page >= pageCount
                          ? null
                          : () => _load(page: _page + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'),
                      iconAlignment: IconAlignment.end,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpirySummary extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _ExpirySummary({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$count $label'),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _ExpiryBatchCard extends StatelessWidget {
  final AdminInventoryBatch batch;

  const _ExpiryBatchCard({required this.batch});

  Future<void> _showDetails(BuildContext context) async {
    final localizations = MaterialLocalizations.of(context);
    String displayDate(DateTime? date) => date == null
        ? 'Not recorded'
        : localizations.formatMediumDate(date.toLocal());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(batch.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch ID: ${batch.id}'),
            Text('SKU: ${batch.sku}'),
            Text('Barcode: ${batch.barcode ?? 'Not recorded'}'),
            Text('Lot number: ${batch.lotNumber ?? 'Not recorded'}'),
            Text('Category: ${batch.categoryName}'),
            Text('Manufacture date: ${displayDate(batch.manufacturedAt)}'),
            Text('Expiry date: ${displayDate(batch.expiresAt)}'),
            Text(
              'Received: ${_formatQuantity(batch.receivedQuantity)} ${batch.unitLabel}',
            ),
            Text(
              'Remaining: ${_formatQuantity(batch.remainingQuantity)} ${batch.unitLabel}',
            ),
            Text('Status: ${batch.expiryStatus.replaceAll('_', ' ')}'),
            Text(
              'Date verification: ${batch.datesVerified ? 'Verified' : 'Not verified'}',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (batch.expiryStatus) {
      'expired' => AppColors.errorText,
      'today' => AppColors.warningText,
      'expiring' => AppColors.warningText,
      'dates_unverified' => AppColors.muted,
      _ => AppColors.successText,
    };
    final statusText = switch (batch.expiryStatus) {
      'expired' => 'Expired',
      'today' => 'Expires today',
      'expiring' =>
        'Expires in ${batch.daysRemaining ?? 0} ${batch.daysRemaining == 1 ? 'day' : 'days'}',
      'dates_unverified' => 'Dates not verified',
      _ => batch.expiresAt == null ? 'No expiry' : 'Within date',
    };
    final localizations = MaterialLocalizations.of(context);
    final expiryDate = batch.expiresAt == null
        ? null
        : localizations.formatMediumDate(batch.expiresAt!.toLocal());
    final manufacturedDate = batch.manufacturedAt == null
        ? null
        : localizations.formatMediumDate(batch.manufacturedAt!.toLocal());
    final weightStock =
        RegExp(r'\b(kg|g)\b', caseSensitive: false).hasMatch(batch.unitLabel);
    final quantity = _formatQuantity(batch.remainingQuantity);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.thumbnail),
                ),
                child: Icon(Icons.inventory_2_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.productName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${batch.sku} · $quantity ${weightStock ? 'kg' : 'units'} remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (batch.lotNumber != null &&
                        batch.lotNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Lot ${batch.lotNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (manufacturedDate != null || expiryDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (manufacturedDate != null) 'MFG $manufacturedDate',
                          if (expiryDate != null) 'EXP $expiryDate',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    AppStatusPill(
                      statusText,
                      variant: switch (batch.expiryStatus) {
                        'expired' => AppStatusVariant.error,
                        'today' || 'expiring' => AppStatusVariant.warning,
                        'dates_unverified' => AppStatusVariant.neutral,
                        _ => AppStatusVariant.success,
                      },
                    ),
                    if (batch.barcode != null && batch.barcode!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Barcode ${batch.barcode}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _ExpiryEmptyState extends StatelessWidget {
  const _ExpiryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          const Text(
            'No batches match these filters.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'New receipts with verified dates will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
