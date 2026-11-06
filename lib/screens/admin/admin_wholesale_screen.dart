import '../../widgets/billing_localized_widgets.dart';
import '../../widgets/initial_room_allocation_field.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/product_sku.dart';
import '../../models/admin_models.dart';
import '../../models/pos_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/offline_pos_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/store_animation.dart';
import '../../widgets/stock_summary_panel.dart';
import '../../services/inventory_changes.dart';

class AdminWholesaleScreen extends StatefulWidget {
  final ApiService api;
  final OfflinePosStore offlineStore;

  const AdminWholesaleScreen(
      {super.key,
      required this.api,
      this.offlineStore = const OfflinePosStore()});

  @override
  State<AdminWholesaleScreen> createState() => _AdminWholesaleScreenState();
}

class _AdminWholesaleScreenState extends State<AdminWholesaleScreen> {
  late final AdminApiService _adminApi =
      AdminApiService(widget.api, offlineStore: widget.offlineStore);
  final _searchController = TextEditingController();
  AdminWholesaleItemPage? _page;
  String? _error;
  bool _loading = true;
  int _pageNumber = 1;
  int _loadRequest = 0;
  Timer? _searchTimer;
  Timer? _offlineSyncTimer;
  Timer? _inventoryTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
    InventoryChanges.revision.addListener(_inventoryChanged);
    _offlineSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_visible && !_loading) unawaited(_load(page: _pageNumber));
    });
  }

  @override
  void dispose() {
    InventoryChanges.revision.removeListener(_inventoryChanged);
    _inventoryTimer?.cancel();
    _searchTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible && !_loading) unawaited(_load(page: _pageNumber));
    _visible = visible;
  }

  void _inventoryChanged() {
    if (!mounted || !_visible || _loading) return;
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(page: _pageNumber);
    });
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _adminApi.syncPendingOfflineProducts();
      final result = await _adminApi.getWholesaleItems(
        page: page,
        search: _searchController.text,
      );
      await widget.offlineStore.mergeCatalog(
        result.items
            .where((item) => item.isActive)
            .map((item) => PosProduct(
                  id: 'wholesale-${item.id}',
                  name: item.name,
                  sku: item.sku,
                  barcode: null,
                  price: item.price,
                  unitLabel: item.unitLabel,
                  available: item.stock,
                  imageUrl: item.imageUrl,
                ))
            .toList(growable: false),
      );
      final pending = await widget.offlineStore.readPendingProducts();
      final projected = await widget.offlineStore.projectLocalStock([
        for (final item in result.items)
          PosProduct(
              id: 'wholesale-${item.id}',
              name: item.name,
              sku: item.sku,
              barcode: null,
              price: item.price,
              unitLabel: item.unitLabel,
              available: item.stock),
      ], freshStock: true);
      final available = {for (final item in projected) item.id: item.available};
      final conflictCount = pending
          .where((entry) =>
              entry['kind'] == 'wholesale' && entry['syncError'] is String)
          .length;
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _page = AdminWholesaleItemPage(pagination: result.pagination, items: [
          for (final item in result.items)
            item.withAvailableStock(
                available['wholesale-${item.id}'] ?? item.stock)
        ]);
        _pageNumber = page;
        _error = conflictCount == 0
            ? null
            : '$conflictCount offline wholesale item(s) need review because the server already has a matching SKU.';
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      final cachedCategories = await widget.offlineStore.readCategories();
      if (!mounted || request != _loadRequest) return;
      if (cachedCategories.isNotEmpty) {
        setState(() {
          _page = const AdminWholesaleItemPage(
            items: [],
            pagination: AdminPagination(page: 1, pageSize: 20, total: 0),
          );
          _pageNumber = page;
          _error =
              'Offline mode: wholesale items will be saved locally and synchronized when the connection returns.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load(page: 1);
    });
  }

  Future<void> _editItem([AdminWholesaleItem? item]) async {
    List<AdminCategory> categories;
    try {
      categories = await _adminApi.getCategories();
    } catch (_) {
      categories = (await widget.offlineStore.readCategories())
          .map(AdminCategory.fromJson)
          .toList(growable: false);
    }
    if (!mounted) return;
    final activeCategories = categories.where((category) => category.isActive);
    if (activeCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: BillingText(
              'Create an active category before adding wholesale items.'),
        ),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WholesaleItemForm(
        api: _adminApi,
        categories: categories,
        item: item,
      ),
    );
    if (saved == true) await _load(page: _pageNumber);
  }

  Future<void> _setActive(AdminWholesaleItem item, bool isActive) async {
    if (!isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const BillingText('Pause wholesale item?'),
          content: BillingText(
            '${item.name} will be hidden from the customer wholesale catalog. '
            'Its inventory and order history will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const BillingText('Keep item'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const BillingText('Pause item'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _adminApi.setWholesaleItemActive(item.id, isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            isActive
                ? '${item.name} is available to wholesale customers.'
                : '${item.name} is paused.',
          ),
        ),
      );
      await _load(page: _pageNumber);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: BillingText(_cleanError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <AdminWholesaleItem>[];
    if (_loading && _page == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _page == null) {
      return _WholesaleLoadError(message: _error!, onRetry: () => _load());
    }
    return RefreshIndicator(
      onRefresh: () => _load(page: _pageNumber),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          StockSummaryPanel(
              api: widget.api,
              wholesale: true,
              offlineStore: widget.offlineStore),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.darkGreen,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BillingText(
                  'Wholesale inventory',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 5),
                BillingText(
                  'Separate items, prices and stock for bulk orders.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final search = TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) {
                  _searchTimer?.cancel();
                  _load(page: 1);
                },
                decoration: BillingInputDecoration(
                  hintText: 'Find a wholesale item',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: BillingIconButton(
                    tooltip: _searchController.text.isEmpty
                        ? 'Search'
                        : 'Clear search',
                    onPressed: _searchController.text.isEmpty
                        ? () {
                            _searchTimer?.cancel();
                            _load(page: 1);
                          }
                        : () {
                            _searchController.clear();
                            _load(page: 1);
                          },
                    icon: Icon(
                      _searchController.text.isEmpty
                          ? Icons.arrow_forward_rounded
                          : Icons.close_rounded,
                    ),
                  ),
                ),
              );
              final add = FilledButton.icon(
                onPressed: () => _editItem(),
                icon: const Icon(Icons.add_rounded),
                label: const BillingText('Add wholesale item'),
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 8), add],
                    )
                  : Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        add,
                      ],
                    );
            },
          ),
          if (_page != null) ...[
            const SizedBox(height: 12),
            BillingText(
              '${_page!.pagination.total} separate wholesale items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            _InlineWholesaleError(
              message: _error!,
              onRetry: () => _load(page: _pageNumber),
            ),
          ],
          const SizedBox(height: 12),
          if (items.isEmpty && !_loading)
            const _WholesaleEmptyState()
          else
            ...items.map(
              (item) => _WholesaleItemCard(
                item: item,
                onEdit: () => _editItem(item),
                onActiveChanged: (value) => _setActive(item, value),
              ),
            ),
          if (_loading && _page != null)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_page != null &&
              _page!.pagination.total > _page!.pagination.pageSize)
            _WholesalePagination(
              pagination: _page!.pagination,
              onPage: (page) => _load(page: page),
            ),
        ],
      ),
    );
  }
}

class _WholesaleItemCard extends StatelessWidget {
  final AdminWholesaleItem item;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  const _WholesaleItemCard({
    required this.item,
    required this.onEdit,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          ProductThumbnail(
            imageUrl: item.imageUrl ?? '',
            size: 42,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(AppRadii.thumbnail),
            backgroundColor: AppColors.thumbnailBlue,
            imageWidthFactor: .77,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BillingText(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                BillingText(
                  '${item.sku} · ${item.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 5),
                BillingText(
                  'Rs. ${item.price.toStringAsFixed(2)} / ${item.unitLabel} · '
                  'Min ${item.minimumQuantity} · Stock ${item.stock}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          BillingIconButton(
            tooltip: 'Edit wholesale item',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          Switch(
            value: item.isActive,
            onChanged: onActiveChanged,
          ),
        ],
      ),
    );
  }
}

class _WholesaleItemForm extends StatefulWidget {
  final AdminApiService api;
  final List<AdminCategory> categories;
  final AdminWholesaleItem? item;

  const _WholesaleItemForm({
    required this.api,
    required this.categories,
    this.item,
  });

  @override
  State<_WholesaleItemForm> createState() => _WholesaleItemFormState();
}

class _WholesaleItemFormState extends State<_WholesaleItemForm> {
  final _roomAllocationKey = GlobalKey<InitialRoomAllocationFieldState>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _minimum;
  late final TextEditingController _unit;
  late final TextEditingController _description;
  late final TextEditingController _origin;
  String? _categoryId;
  Uint8List? _imageBytes;
  String? _imageName;
  bool _removeImage = false;
  bool _saving = false;
  String? _error;

  List<AdminCategory> get _activeCategories =>
      widget.categories.where((category) => category.isActive).toList();

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _sku = TextEditingController(text: item?.sku ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _price = TextEditingController(text: item?.price.toString() ?? '');
    _stock = TextEditingController(text: item?.stock.toString() ?? '0');
    _minimum =
        TextEditingController(text: item?.minimumQuantity.toString() ?? '1');
    _unit = TextEditingController(text: item?.unitLabel ?? '1 pc');
    _description = TextEditingController(text: item?.description ?? '');
    _origin = TextEditingController(text: item?.origin ?? '');
    _categoryId = item?.categoryId ??
        (_activeCategories.isEmpty ? null : _activeCategories.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _brand.dispose();
    _price.dispose();
    _stock.dispose();
    _minimum.dispose();
    _unit.dispose();
    _description.dispose();
    _origin.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isEmpty) return;
      final file = result.first;
      final bytes = await file.readAsBytes();
      final extension = file.extension?.toLowerCase();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Choose an image smaller than 5 MB.');
      }
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw Exception('Choose a JPEG, PNG, or WebP image.');
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _removeImage = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _cleanError(error));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (widget.item == null &&
        !(_roomAllocationKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final category = _activeCategories.firstWhere(
      (item) => item.id == _categoryId,
    );
    final name = _name.text.trim();
    final sku = _sku.text.trim().toUpperCase().isEmpty
        ? generateStoreSku(
            categorySlug: 'wh-${category.slug}',
            productName: name,
          )
        : _sku.text.trim().toUpperCase();
    final slug = _slugify(name).isEmpty
        ? _slugify(sku).isEmpty
            ? 'wholesale-${DateTime.now().millisecondsSinceEpoch}'
            : _slugify(sku)
        : _slugify(name);
    final fields = <String, dynamic>{
      'name': name,
      'sku': sku,
      'slug': slug,
      'categoryId': category.id,
      'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      'price': double.parse(_price.text.trim()),
      'stock': int.parse(_stock.text.trim()),
      'minimumQuantity': int.parse(_minimum.text.trim()),
      'unitLabel': _unit.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'origin': _origin.text.trim().isEmpty ? null : _origin.text.trim(),
      'imageUrl': _removeImage ? null : widget.item?.imageUrl,
      if (widget.item == null &&
          _roomAllocationKey.currentState?.allocations != null)
        'initialRoomAllocations': _roomAllocationKey.currentState!.allocations,
    };
    try {
      if (widget.item == null) {
        await widget.api.createWholesaleItem(
          fields,
          imageBytes: _imageBytes,
          imageName: _imageName,
        );
      } else {
        await widget.api.updateWholesaleItem(
          widget.item!.id,
          fields,
          imageBytes: _imageBytes,
          imageName: _imageName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiNetworkException {
      if (widget.item != null) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error =
                'Editing an existing wholesale item requires a connection. It was not queued as a duplicate.';
          });
        }
        return;
      }
      await widget.api.offlineStore.queueWholesaleItem(fields);
      if (mounted) Navigator.pop(context, true);
    } on ApiTimeoutException {
      if (widget.item != null) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error =
                'Editing an existing wholesale item requires a connection. It was not queued as a duplicate.';
          });
        }
        return;
      }
      await widget.api.offlineStore.queueWholesaleItem(fields);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: BillingText(
          widget.item == null ? 'Add wholesale item' : 'Edit wholesale item'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BillingTextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration:
                      const BillingInputDecoration(labelText: 'Item name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an item name'
                      : null,
                ),
                const SizedBox(height: 10),
                BillingTextFormField(
                  controller: _sku,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const BillingInputDecoration(
                    labelText: 'Wholesale SKU (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _categoryId,
                  decoration:
                      const BillingInputDecoration(labelText: 'Category'),
                  items: _activeCategories
                      .map((category) => DropdownMenuItem(
                            value: category.id,
                            child: BillingText(category.name),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Choose a category' : null,
                ),
                const SizedBox(height: 10),
                BillingTextFormField(
                  controller: _brand,
                  decoration: const BillingInputDecoration(
                      labelText: 'Brand (optional)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        _price,
                        'Wholesale price (Rs.)',
                        decimal: true,
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');
                          return number == null ||
                                  !number.isFinite ||
                                  number <= 0
                              ? 'Enter a price above 0'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(
                        _stock,
                        'Stock',
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null || number < 0
                              ? 'Enter 0 or more'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.item == null)
                  InitialRoomAllocationField(
                      key: _roomAllocationKey,
                      api: widget.api,
                      stock: _stock,
                      enabled: !_saving),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        _minimum,
                        'Minimum quantity',
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null || number < 1 || number > 100
                              ? 'Enter a quantity from 1 to 100'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BillingTextFormField(
                        controller: _unit,
                        decoration:
                            const BillingInputDecoration(labelText: 'Unit'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a unit'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: BillingText(_imageName ??
                      (widget.item?.imageUrl != null && !_removeImage
                          ? 'Replace item image'
                          : 'Choose item image')),
                ),
                if (widget.item?.imageUrl != null || _imageBytes != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _imageBytes = null;
                                _imageName = null;
                                _removeImage = true;
                              }),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const BillingText('Remove image'),
                    ),
                  ),
                const SizedBox(height: 10),
                BillingTextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const BillingInputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                BillingTextFormField(
                  controller: _origin,
                  decoration: const BillingInputDecoration(
                    labelText: 'Origin (optional)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
          onPressed: _saving ? null : () => Navigator.pop(context, false),
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
              : const BillingText('Save item'),
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    String? Function(String?)? validator,
  }) {
    return BillingTextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: BillingInputDecoration(labelText: label),
      validator: validator,
    );
  }
}

class _WholesalePagination extends StatelessWidget {
  final AdminPagination pagination;
  final ValueChanged<int> onPage;

  const _WholesalePagination({
    required this.pagination,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount =
        (pagination.total / pagination.pageSize).ceil().clamp(1, 100000);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BillingIconButton(
          onPressed:
              pagination.page > 1 ? () => onPage(pagination.page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        BillingText('${pagination.page} / $pageCount'),
        BillingIconButton(
          onPressed: pagination.page < pageCount
              ? () => onPage(pagination.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _WholesaleLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WholesaleLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'Wholesale unavailable',
        message: message,
        retryLabel: 'Retry',
        onRetry: onRetry,
      );
}

class _InlineWholesaleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineWholesaleError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(
          Icons.cloud_off_outlined,
          color: AppColors.errorText,
        ),
        title:
            BillingText(message, style: Theme.of(context).textTheme.bodySmall),
        trailing: BillingIconButton(
          tooltip: 'Retry',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
}

class _WholesaleEmptyState extends StatelessWidget {
  const _WholesaleEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.muted,
            ),
            const SizedBox(height: 10),
            const BillingText(
              'No wholesale items yet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            BillingText(
              'Add a separate wholesale item to make it available to bulk customers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
