import 'package:flutter/material.dart';

import '../../models/pos_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminBillingShiftHistoryScreen extends StatefulWidget {
  const AdminBillingShiftHistoryScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminBillingShiftHistoryScreen> createState() =>
      _AdminBillingShiftHistoryScreenState();
}

class _AdminBillingShiftHistoryScreenState
    extends State<AdminBillingShiftHistoryScreen> {
  static const _pageSize = 20;

  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<PosShiftHistory> _shifts = const [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  int get _pageCount => _total == 0 ? 0 : (_total / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final requestedPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _adminApi.getPosShiftHistory(
        page: requestedPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _shifts = result.shifts;
        _page = result.page;
        _total = result.total;
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

  String _formatDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  Widget _shiftCard(BuildContext context, PosShiftHistory shift) {
    final isOpen = shift.status == 'OPEN';
    final variance = shift.variance;
    final varianceColor = variance == null || variance == 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : variance > 0
            ? Colors.green.shade800
            : Theme.of(context).colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: isOpen
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shift.cashierName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(isOpen ? 'OPEN' : 'CLOSED'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Opened ${_formatDateTime(context, shift.openedAt)}'),
            if (shift.closedAt != null)
              Text('Closed ${_formatDateTime(context, shift.closedAt!)}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _amount('Opening cash', shift.openingCash),
                if (shift.expectedClosingCash != null)
                  _amount('Expected', shift.expectedClosingCash!),
                if (shift.actualClosingCash != null)
                  _amount('Counted', shift.actualClosingCash!),
                if (variance != null)
                  Text(
                    variance == 0
                        ? 'Balanced'
                        : '${variance > 0 ? 'Over' : 'Short'} by '
                            '${_money(variance.abs())}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: varianceColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, double amount) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            _money(amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cashier shift history')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Review register closeouts and cash variances across cashiers.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: _loading ? null : () => _load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
                if (_total > _pageSize)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${((_page - 1) * _pageSize) + 1}–'
                          '${(_page * _pageSize).clamp(0, _total)}'
                          ' of $_total shifts',
                        ),
                        IconButton(
                          tooltip: 'Previous shifts page',
                          onPressed: _loading || _page <= 1
                              ? null
                              : () => _load(page: _page - 1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          tooltip: 'Next shifts page',
                          onPressed: _loading || _page >= _pageCount
                              ? null
                              : () => _load(page: _page + 1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _shifts.isEmpty
                          ? const Center(
                              child:
                                  Text('No cashier shifts have been recorded.'),
                            )
                          : ListView.separated(
                              itemCount: _shifts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _shiftCard(context, _shifts[index]),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
