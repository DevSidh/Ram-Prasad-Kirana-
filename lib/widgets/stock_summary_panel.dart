import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../models/stock_summary.dart';
import '../services/admin_api_service.dart';
import '../services/api_service.dart';
import '../services/inventory_changes.dart';
import '../services/offline_pos_store.dart';
import 'billing_localized_widgets.dart';

class StockSummaryPanel extends StatefulWidget {
  const StockSummaryPanel(
      {super.key,
      required this.api,
      this.drinksOnly = false,
      this.wholesale = false,
      this.offlineStore = const OfflinePosStore()});
  final ApiService api;
  final bool drinksOnly;
  final bool wholesale;
  final OfflinePosStore offlineStore;
  @override
  State<StockSummaryPanel> createState() => _StockSummaryPanelState();
}

class _StockSummaryPanelState extends State<StockSummaryPanel> {
  StockSummary? _summary;
  int? _totalProducts;
  String? _error;
  Timer? _timer;
  Timer? _debounce;
  bool _busy = false;
  bool _visible = false;
  bool _stale = false;
  @override
  void initState() {
    super.initState();
    InventoryChanges.revision.addListener(_changed);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _changed());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) unawaited(_load());
    _visible = visible;
  }

  void _changed() {
    if (!_visible) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    if (_busy || !mounted) {
      _stale = true;
      return;
    }
    _busy = true;
    _stale = false;
    try {
      final api = AdminApiService(widget.api);
      final List<PosProduct> baseline;
      final int totalProducts;
      if (widget.wholesale) {
        final items = await api.getAllWholesaleItems();
        totalProducts = items.map((item) => item.id).toSet().length;
        baseline = items
            .where((p) => p.isActive)
            .map((p) => PosProduct(
                id: 'wholesale-${p.id}',
                name: p.name,
                sku: p.sku,
                barcode: null,
                price: p.price,
                unitLabel: p.unitLabel,
                available: p.stock))
            .toList();
      } else {
        final items = (await api.getAllProducts())
            .where((item) => !widget.drinksOnly || item.isVendingDrink)
            .toList();
        totalProducts = items.map((item) => item.id).toSet().length;
        baseline = items
            .where(
                (p) => p.isActive && (!widget.drinksOnly || p.isVendingDrink))
            .map((p) => PosProduct(
                id: p.id,
                name: p.name,
                sku: p.sku,
                barcode: p.barcode,
                price: p.price,
                unitLabel: p.unitLabel,
                available: p.posStockUnits))
            .toList();
      }
      final projected = await widget.offlineStore
          .projectLocalStock(baseline, freshStock: true);
      if (!mounted) return;
      setState(() {
        _summary = StockSummary.fromProducts(projected);
        _totalProducts = totalProducts;
        _error = null;
      });
    } catch (error) {
      debugPrint('Could not refresh stock totals: $error');
      if (mounted) {
        setState(
            () => _error = 'Stock totals could not be refreshed. Try again.');
      }
    } finally {
      _busy = false;
      if (_stale && mounted && _visible) _changed();
    }
  }

  @override
  void dispose() {
    InventoryChanges.revision.removeListener(_changed);
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: BillingText('Available stock summary',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold))),
                        BillingIconButton(
                            onPressed: _load,
                            tooltip: 'Refresh stock totals',
                            icon: const Icon(Icons.refresh))
                      ]),
                      if (_summary == null && _error == null)
                        const LinearProgressIndicator(),
                      if (_summary != null)
                        Wrap(spacing: 24, runSpacing: 12, children: [
                          BillingText('Total products: $_totalProducts',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          BillingText(
                              'Active products: ${_summary!.productCount}'),
                          for (final entry in _summary!.quantities.entries)
                            BillingText(
                                '${entry.key}: ${StockSummary.quantity(entry.value)}'),
                        ]),
                      const SizedBox(height: 8),
                      const BillingText(
                          'Available after reservations and local sales. Pack sizes are counted separately; 1 L means one sealed 1 L pack.'),
                      const BillingText(
                          'Available stock totals include active products only.'),
                      if (_error != null)
                        BillingText(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]))),
      );
}
