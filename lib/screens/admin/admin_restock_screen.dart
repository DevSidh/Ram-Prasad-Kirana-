import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminRestockScreen extends StatefulWidget {
  final ApiService api;

  const AdminRestockScreen({super.key, required this.api});

  @override
  State<AdminRestockScreen> createState() => _AdminRestockScreenState();
}

class _AdminRestockScreenState extends State<AdminRestockScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _adminApi.getAllProducts(
        stock: 'restock',
        sort: 'stock_asc',
      );
      if (!mounted) return;
      setState(() {
        _products = products;
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

  Future<void> _restock(AdminProduct product) async {
    final updatedProduct = await showDialog<AdminProduct>(
      context: context,
      builder: (_) => _RestockDialog(
        api: _adminApi,
        product: product,
      ),
    );
    if (updatedProduct == null || !mounted) return;
    setState(() {
      _products = _products
          .map((item) => item.id == updatedProduct.id ? updatedProduct : item)
          .where((item) => item.stock <= item.lowStockThreshold)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} stock updated.')),
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminRestockHistoryScreen(api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final outOfStockCount =
        _products.where((product) => product.stock == 0).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Restock queue',
            style: TextStyle(
              color: AppConstants.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active products at or below their low-stock threshold.',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QueueCount(
                label: '${_products.length} to replenish',
                icon: Icons.inventory_2_outlined,
                color: AppConstants.primaryDark,
              ),
              _QueueCount(
                label: '$outOfStockCount out of stock',
                icon: Icons.error_outline_rounded,
                color: outOfStockCount == 0
                    ? AppConstants.textMuted
                    : Colors.red.shade700,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Receipt history'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 14),
          if (_products.isEmpty)
            const _RestockEmptyState()
          else
            ..._products.map(
              (product) => _RestockProductCard(
                product: product,
                onRestock: () => _restock(product),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminRestockHistoryScreen extends StatefulWidget {
  final ApiService api;

  const AdminRestockHistoryScreen({super.key, required this.api});

  @override
  State<AdminRestockHistoryScreen> createState() =>
      _AdminRestockHistoryScreenState();
}

class _AdminRestockHistoryScreenState extends State<AdminRestockHistoryScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  AdminRestockHistoryPage? _history;
  bool _loading = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _adminApi.getRestockHistory(page: page);
      if (!mounted) return;
      setState(() {
        _history = history;
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _history == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt history')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _history == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt history')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final history = _history!;
    final pageCount =
        (history.pagination.total / history.pagination.pageSize).ceil();
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt history')),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'Stock receipts recorded by admin staff.',
              style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 14),
            if (history.receipts.isEmpty)
              const _RestockHistoryEmptyState()
            else
              ...history.receipts.map(
                (receipt) => _RestockReceiptCard(receipt: receipt),
              ),
            if (pageCount > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _page > 1 && !_loading
                        ? () => _load(page: _page - 1)
                        : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page $_page of $pageCount'),
                  TextButton(
                    onPressed: _page < pageCount && !_loading
                        ? () => _load(page: _page + 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RestockReceiptCard extends StatelessWidget {
  final AdminRestockReceipt receipt;

  const _RestockReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final localTime = receipt.createdAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(localTime);
    final time = TimeOfDay.fromDateTime(localTime).format(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppConstants.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${receipt.productSku} · $date · $time',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              Text(
                '+${receipt.quantity} × ${receipt.unitLabel}',
                style: TextStyle(
                  color: AppConstants.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${receipt.balanceAfter} available after receipt',
                style: TextStyle(color: AppConstants.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            receipt.staffName == null
                ? 'Staff account unavailable for this receipt'
                : 'Recorded by ${receipt.staffName}',
            style: TextStyle(
              color: AppConstants.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (receipt.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              receipt.notes!,
              style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestockHistoryEmptyState extends StatelessWidget {
  const _RestockHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 40, color: AppConstants.textMuted),
          const SizedBox(height: 10),
          Text(
            'No stock receipts yet',
            style: TextStyle(
              color: AppConstants.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCount extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _QueueCount({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestockProductCard extends StatelessWidget {
  final AdminProduct product;
  final VoidCallback onRestock;

  const _RestockProductCard({
    required this.product,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock == 0;
    final statusColor =
        isOutOfStock ? Colors.red.shade700 : Colors.orange.shade800;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOutOfStock
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.inventory_2_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppConstants.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            product.brand?.isNotEmpty == true ? product.brand! : product.sku,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '${product.stock} available',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Alert at ${product.lowStockThreshold}',
                style: TextStyle(color: AppConstants.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onRestock,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Restock'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockEmptyState extends StatelessWidget {
  const _RestockEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 42,
            color: AppConstants.primaryDark,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing to replenish',
            style: TextStyle(
              color: AppConstants.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Products needing stock will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RestockDialog extends StatefulWidget {
  final AdminApiService api;
  final AdminProduct product;

  const _RestockDialog({required this.api, required this.product});

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  late final TextEditingController _quantityController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final suggestedQuantity =
        widget.product.lowStockThreshold - widget.product.stock + 1;
    _quantityController = TextEditingController(
      text: (suggestedQuantity > 0 ? suggestedQuantity : 1).toString(),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quantity = int.parse(_quantityController.text.trim());
      final product =
          await widget.api.restockProduct(widget.product.id, quantity);
      if (mounted) Navigator.pop(context, product);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record restock'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.product.name),
              const SizedBox(height: 4),
              Text(
                'Current available stock: ${widget.product.stock}',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity received',
                  helperText: 'This amount will be added to current stock.',
                ),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  if (quantity == null || quantity < 1 || quantity > 1000000) {
                    return 'Enter a whole number from 1 to 1,000,000';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add to stock'),
        ),
      ],
    );
  }
}
