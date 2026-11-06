import '../../widgets/billing_localized_widgets.dart';
import '../../core/billing_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/store_animation.dart';
import '../../widgets/product_identity.dart';
import '../../widgets/product_thumbnail.dart';
import 'admin_inventory_expiry_screen.dart';
import 'admin_supplier_bills_screen.dart';

Future<AdminProduct?> showAddStockDialog(
        BuildContext context, AdminApiService api, AdminProduct product) =>
    showDialog<AdminProduct>(
        context: context,
        builder: (_) => _RestockDialog(api: api, product: product));

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
  int _loadRequest = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _adminApi.getAllProducts(
        sort: 'stock_asc',
      );
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
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
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: BillingText('${product.name} stock updated.')),
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminRestockHistoryScreen(api: widget.api),
      ),
    );
  }

  Future<void> _openExpiry() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminInventoryExpiryScreen(api: widget.api),
      ),
    );
  }

  Future<void> _openSupplierBills() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminSupplierBillsScreen(api: widget.api),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return StorePageError(
        title: 'Restock items unavailable',
        message: _error!,
        retryLabel: 'Try again',
        onRetry: _load,
      );
    }

    final outOfStockCount =
        _products.where((product) => product.availableStock == 0).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          BillingText(
            'Add stock directly. No supplier bill or invoice number is required.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          AppSurface(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QueueCount(
                  label:
                      '${_products.where((product) => product.availableStock <= product.lowStockThreshold).length} to replenish',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
                _QueueCount(
                  label: '$outOfStockCount out of stock',
                  icon: Icons.error_outline_rounded,
                  color: outOfStockCount == 0
                      ? AppColors.muted
                      : AppColors.errorText,
                ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              FilledButton.icon(
                onPressed: _openSupplierBills,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const BillingText('Supplier bills (optional)'),
              ),
              TextButton.icon(
                onPressed: _openExpiry,
                icon: const Icon(Icons.event_busy_outlined),
                label: const BillingText('Near to Expiry'),
              ),
              TextButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history_rounded),
                label: const BillingText('Receipt history'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            BillingText(_error!, style: TextStyle(color: AppColors.errorText)),
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
  DateTime? _selectedDay;
  final _search = TextEditingController();
  String _movementType = 'RESTOCKED';
  int _request = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _adminApi.getRestockHistory(
        page: page,
        day: _selectedDay,
        movementType: _movementType,
        search: _search.text,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _history = history;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (!mounted || day == null) return;
    setState(() => _selectedDay = day);
    await _load();
  }

  Future<void> _exportPage() async {
    final history = _history;
    if (history == null) return;
    String cell(String value) {
      final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final rows = <List<String>>[
      [
        'Movement ID',
        'Date',
        'Product',
        'SKU',
        'Type',
        'Quantity',
        'Available after',
        'Unit',
        'Staff',
        'Reference',
        'Reason'
      ],
      for (final movement in history.receipts)
        [
          movement.id,
          movement.createdAt.toLocal().toString(),
          movement.productName,
          movement.productSku,
          movement.movementType,
          '${movement.quantity}',
          '${movement.balanceAfter}',
          movement.unitLabel,
          movement.staffName ?? '',
          movement.referenceId ?? '',
          movement.notes ?? '',
        ],
    ];
    try {
      await FilePicker.saveFile(
        fileName: 'Stock-movements-page-$_page.csv',
        bytes: Uint8List.fromList(utf8.encode(
            '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n')),
        mimeType: 'text/csv',
        allowedExtensions: const ['csv'],
        dialogTitle: 'Export the displayed stock-history page',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: BillingText('Export failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _history == null) {
      return Scaffold(
        appBar: AppBar(title: const BillingText('Receipt history')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _history == null) {
      return Scaffold(
        appBar: AppBar(title: const BillingText('Receipt history')),
        body: StorePageError(
          title: 'Receipt history unavailable',
          message: _error!,
          retryLabel: 'Try again',
          onRetry: _load,
        ),
      );
    }

    final history = _history!;
    final pageCount =
        (history.pagination.total / history.pagination.pageSize).ceil();
    return Scaffold(
      appBar: AppBar(title: const BillingText('Receipt history')),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
          children: [
            BillingText(
              'Recorded product stock movements. Receipt history remains the default filter.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: BillingInputDecoration(
                        labelText: 'Product, SKU, reference, staff or reason',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: BillingIconButton(
                            onPressed: _loading ? null : () => _load(),
                            icon: const Icon(Icons.arrow_forward)),
                      ),
                    )),
                SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _movementType,
                      isExpanded: true,
                      decoration:
                          const BillingInputDecoration(labelText: 'Movement'),
                      items: const [
                        DropdownMenuItem(
                            value: 'RESTOCKED',
                            child: BillingText('Stock receipts')),
                        DropdownMenuItem(
                            value: 'ALL', child: BillingText('All movements')),
                        DropdownMenuItem(
                            value: 'PURCHASED',
                            child: BillingText('Sales deductions')),
                        DropdownMenuItem(
                            value: 'RESERVED',
                            child: BillingText('Reservations')),
                        DropdownMenuItem(
                            value: 'RELEASED',
                            child: BillingText('Released stock')),
                        DropdownMenuItem(
                            value: 'ADJUSTED',
                            child: BillingText('Adjustments / returns')),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(
                                  () => _movementType = value ?? 'RESTOCKED');
                              unawaited(_load());
                            },
                    )),
                OutlinedButton.icon(
                    onPressed: _loading ? null : _exportPage,
                    icon: const Icon(Icons.download_outlined),
                    label: const BillingText('Export this page')),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _selectDay,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: BillingText(
                    _selectedDay == null
                        ? 'Filter by day'
                        : DateFormat(
                                'EEE, d MMM yyyy', BillingStrings.languageCode)
                            .format(_selectedDay!),
                  ),
                ),
                if (_selectedDay != null)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _selectedDay = null);
                            _load();
                          },
                    child: const BillingText('Clear day'),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              BillingText(_error!,
                  style: TextStyle(color: AppColors.errorText)),
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
                    child: const BillingText('Previous'),
                  ),
                  BillingText('Page $_page of $pageCount'),
                  TextButton(
                    onPressed: _page < pageCount && !_loading
                        ? () => _load(page: _page + 1)
                        : null,
                    child: const BillingText('Next'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductIdentity(
              name: receipt.productName,
              sku: receipt.productSku,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          BillingText(
            '${receipt.productSku} · $date · $time',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              BillingText(
                _receiptQuantityLabel(receipt),
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              BillingText(
                '${_formatQuantity(receipt.balanceAfter)} available after movement',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 7),
          BillingText(
            receipt.staffName == null
                ? 'Staff account unavailable for this receipt'
                : 'Recorded by ${receipt.staffName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (receipt.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            BillingText(
              receipt.notes!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (receipt.referenceId?.isNotEmpty == true)
            SelectableText(
                BillingStrings.tr('Reference: ${receipt.referenceId}'),
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatQuantity(double quantity) => quantity % 1 == 0
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  String _receiptQuantityLabel(AdminRestockReceipt receipt) {
    if (receipt.movementType != 'RESTOCKED') {
      final unit =
          RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
                  .hasMatch(receipt.unitLabel)
              ? 'kg'
              : 'units';
      return '${receipt.movementType}: ${_formatQuantity(receipt.quantity)} $unit';
    }
    if (RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
        .hasMatch(receipt.unitLabel)) {
      return '+${_formatQuantity(receipt.quantity)} kg';
    }
    return '+${_formatQuantity(receipt.quantity)} × ${receipt.unitLabel}';
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
          Icon(Icons.history_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          BillingText(
            'No stock receipts yet',
            style: Theme.of(context).textTheme.titleMedium,
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
    return AppStatusPill(
      label,
      icon: icon,
      variant: color == AppColors.errorText
          ? AppStatusVariant.error
          : AppStatusVariant.neutral,
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
    final isOutOfStock = product.availableStock == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppRowCard(
        title: product.name,
        subtitle:
            '${product.brand?.isNotEmpty == true ? product.brand : product.sku}'
            ' · ${product.availableStockLabel} available'
            ' · Alert at ${product.lowStockThreshold}',
        leading: ProductThumbnail(imageUrl: product.imageUrl ?? '', size: 56),
        tint: isOutOfStock ? AppColors.thumbnailRed : AppColors.thumbnailAmber,
        trailing: FilledButton.icon(
          onPressed: onRestock,
          icon: const Icon(Icons.add_box_outlined, size: 18),
          label: const BillingText('Restock'),
        ),
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
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          BillingText(
            'Nothing to replenish',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          BillingText(
            'Products needing stock will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
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
  late final TextEditingController _lotNumberController;
  late final TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();
  DateTime? _manufacturedAt;
  DateTime? _expiresAt;
  bool _noExpiry = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final suggestedQuantity =
        widget.product.lowStockThreshold - widget.product.availableStock + 1;
    _quantityController = TextEditingController(
      text: suggestedQuantity > 0
          ? suggestedQuantity.toStringAsFixed(3).replaceFirst(
                RegExp(r'\.?0+$'),
                '',
              )
          : '1',
    );
    _lotNumberController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _lotNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({
    required bool manufactureDate,
    ValueChanged<DateTime>? onSelected,
  }) async {
    final selectedDate = manufactureDate ? _manufacturedAt : _expiresAt;
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ??
          (manufactureDate
              ? DateTime.now()
              : DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime(2000),
      lastDate: manufactureDate ? DateTime.now() : DateTime(2100),
    );
    if (!mounted || date == null) return;
    setState(() {
      if (manufactureDate) {
        _manufacturedAt = date;
      } else {
        _expiresAt = date;
      }
    });
    onSelected?.call(date);
  }

  DateTime _dateAsUtc(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  String _formatDate(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quantity = double.parse(_quantityController.text.trim());
      final product = await widget.api.restockProduct(
        widget.product.id,
        {
          'quantity': quantity,
          'lotNumber': _lotNumberController.text.trim().isEmpty
              ? null
              : _lotNumberController.text.trim(),
          'manufacturedAt': _dateAsUtc(_manufacturedAt!).toIso8601String(),
          'expiresAt':
              _noExpiry ? null : _dateAsUtc(_expiresAt!).toIso8601String(),
          'noExpiry': _noExpiry,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        },
      );
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
      title: const BillingText('Record restock'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BillingText(
                    'No supplier bill or invoice number is required.'),
                ProductIdentity(
                    name: widget.product.name,
                    imageUrl: widget.product.imageUrl,
                    productId: widget.product.id,
                    sku: widget.product.sku),
                const SizedBox(height: 4),
                BillingText(
                  'Current available stock: ${widget.product.availableStockLabel}',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                BillingTextFormField(
                  controller: _quantityController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const BillingInputDecoration(
                    labelText: 'Quantity received',
                    helperText: 'This amount will be added to current stock.',
                  ),
                  validator: (value) {
                    final quantity = double.tryParse(value?.trim() ?? '');
                    if (quantity == null ||
                        !quantity.isFinite ||
                        quantity <= 0 ||
                        quantity > 1000000) {
                      return 'Enter a positive quantity up to 1,000,000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                BillingTextFormField(
                  controller: _lotNumberController,
                  enabled: !_saving,
                  decoration: const BillingInputDecoration(
                    labelText: 'Batch / lot number (optional)',
                  ),
                ),
                FormField<DateTime>(
                  initialValue: _manufacturedAt,
                  validator: (value) {
                    if (value == null) return 'Choose a manufacture date.';
                    if (DateTime(value.year, value.month, value.day)
                        .isAfter(DateTime.now())) {
                      return 'Manufacture date cannot be in the future.';
                    }
                    return null;
                  },
                  builder: (field) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.factory_outlined),
                    title: BillingText(
                      _manufacturedAt == null
                          ? 'Manufacture date (MFG)'
                          : 'MFG · ${_formatDate(_manufacturedAt!)}',
                    ),
                    subtitle: field.errorText == null
                        ? null
                        : BillingText(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: _saving
                        ? null
                        : () => _chooseDate(
                              manufactureDate: true,
                              onSelected: field.didChange,
                            ),
                  ),
                ),
                FormField<DateTime>(
                  initialValue: _expiresAt,
                  validator: (value) {
                    if (_noExpiry) return null;
                    if (value == null) return 'Choose an expiry date.';
                    if (_manufacturedAt != null &&
                        !value.isAfter(_manufacturedAt!)) {
                      return 'Expiry must be after manufacture.';
                    }
                    return null;
                  },
                  builder: (field) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: BillingText(
                      _noExpiry
                          ? 'No expiry date confirmed'
                          : _expiresAt == null
                              ? 'Expiry date (EXP)'
                              : 'EXP · ${_formatDate(_expiresAt!)}',
                    ),
                    subtitle: field.errorText == null
                        ? null
                        : BillingText(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                    trailing: _noExpiry
                        ? null
                        : const Icon(Icons.calendar_month_outlined),
                    onTap: _saving || _noExpiry
                        ? null
                        : () => _chooseDate(
                              manufactureDate: false,
                              onSelected: field.didChange,
                            ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const BillingText('This product does not expire'),
                  value: _noExpiry,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _noExpiry = value ?? false;
                            if (_noExpiry) _expiresAt = null;
                          }),
                ),
                BillingTextFormField(
                  controller: _notesController,
                  enabled: !_saving,
                  maxLength: 500,
                  decoration: const BillingInputDecoration(
                    labelText: 'Receipt notes (optional)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  BillingText(
                    _error!,
                    style: TextStyle(color: AppColors.errorText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const BillingText('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const BillingText('Add to stock'),
        ),
      ],
    );
  }
}
