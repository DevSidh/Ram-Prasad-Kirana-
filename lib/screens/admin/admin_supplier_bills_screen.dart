import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';

class AdminSupplierBillsScreen extends StatefulWidget {
  const AdminSupplierBillsScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminSupplierBillsScreen> createState() =>
      _AdminSupplierBillsScreenState();
}

class _AdminSupplierBillsScreenState extends State<AdminSupplierBillsScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  AdminSupplierPurchaseBillPage? _page;
  DateTime? _selectedDay;
  String? _error;
  bool _loading = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _adminApi.getSupplierPurchaseBills(
        page: page,
        search: _searchController.text,
        day: _selectedDay,
      );
      if (!mounted) return;
      setState(() {
        _page = result;
        _currentPage = page;
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

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load(page: 1);
    });
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (!mounted || date == null) return;
    setState(() => _selectedDay = date);
    await _load(page: 1);
  }

  Future<void> _recordBill() async {
    final bill = await showDialog<AdminSupplierPurchaseBill>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SupplierBillFormDialog(api: _adminApi),
    );
    if (!mounted || bill == null) return;
    await _load(page: 1);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Supplier bill, inventory and photo synced for all admin devices.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bills = _page?.bills ?? const <AdminSupplierPurchaseBill>[];
    final pageCount = _page == null
        ? 1
        : (_page!.total / _page!.pageSize).ceil().clamp(1, 100000);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier bills'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _recordBill,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record supplier bill'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _currentPage),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
          children: [
            const AppBanner(
              message:
                  'Record the supplier invoice after delivery. Received quantities are added to inventory immediately.',
              icon: Icons.inventory_2_outlined,
              variant: AppStatusVariant.neutral,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) {
                    _searchTimer?.cancel();
                    _load(page: 1);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search supplier, invoice or delivery person',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: _searchController.text.isEmpty
                          ? 'Search'
                          : 'Clear search',
                      onPressed: _searchController.text.isEmpty
                          ? null
                          : () {
                              _searchController.clear();
                              _load(page: 1);
                            },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                );
                final dateFilter = OutlinedButton.icon(
                  onPressed: _selectDay,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _selectedDay == null
                        ? 'All dates'
                        : DateFormat('d MMM yyyy').format(_selectedDay!),
                  ),
                );
                if (constraints.maxWidth < 580) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 8),
                      dateFilter,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    dateFilter,
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppBanner(
                message: _error!,
                variant: AppStatusVariant.error,
                icon: Icons.error_outline_rounded,
                trailing: TextButton(
                  onPressed: _loading ? null : () => _load(page: _currentPage),
                  child: const Text('Retry'),
                ),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_page != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_page!.total} supplier ${_page!.total == 1 ? 'bill' : 'bills'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (_page == null && _loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (bills.isEmpty && _error == null)
              const _SupplierBillsEmptyState()
            else
              ...bills.map(
                (bill) => _SupplierBillCard(bill: bill, api: _adminApi),
              ),
            if (pageCount > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _loading || _currentPage <= 1
                        ? null
                        : () => _load(page: _currentPage - 1),
                    child: const Text('Previous'),
                  ),
                  Text('Page $_currentPage of $pageCount'),
                  TextButton(
                    onPressed: _loading || _currentPage >= pageCount
                        ? null
                        : () => _load(page: _currentPage + 1),
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

class _SupplierBillCard extends StatelessWidget {
  const _SupplierBillCard({required this.bill, required this.api});

  final AdminSupplierPurchaseBill bill;
  final AdminApiService api;

  @override
  Widget build(BuildContext context) {
    final invoiceDate =
        MaterialLocalizations.of(context).formatMediumDate(bill.invoiceDate);
    final createdDate =
        MaterialLocalizations.of(context).formatMediumDate(bill.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bill.supplierName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const AppStatusPill(
                  'Received',
                  variant: AppStatusVariant.success,
                  icon: Icons.check_rounded,
                ),
                const SizedBox(width: 6),
                if (bill.hasPhoto)
                  _BillPhotoButton(bill: bill, api: api)
                else
                  FutureBuilder<String?>(
                    future: _SupplierBillPhotoStore.getPath(bill.id),
                    builder: (context, snapshot) {
                      final path = snapshot.data;
                      if (path == null || !File(path).existsSync()) {
                        return const SizedBox(width: 40);
                      }
                      return _BillPhotoButton(
                        bill: bill,
                        api: api,
                        legacyPath: path,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Invoice ${bill.invoiceNumber} · $invoiceDate · Entered $createdDate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (bill.deliveryPerson?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Delivered by ${bill.deliveryPerson}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (bill.supplierPhone?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                'Supplier phone ${bill.supplierPhone}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 18),
            for (final item in bill.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.name} · ${item.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${_quantity(item.quantity)} × ${_money(item.unitCost)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (bill.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                bill.notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 18),
            Row(
              children: [
                const Expanded(child: Text('Bill total')),
                Text(
                  _money(bill.totalCost),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _quantity(double value) => value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  String _money(double value) =>
      NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2).format(value);
}

class _BillPhotoButton extends StatelessWidget {
  const _BillPhotoButton({
    required this.bill,
    required this.api,
    this.legacyPath,
  });

  final AdminSupplierPurchaseBill bill;
  final AdminApiService api;
  final String? legacyPath;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'View supplier bill photo',
      onPressed: () async {
        try {
          final bytes = bill.hasPhoto
              ? await api.getSupplierPurchaseBillPhoto(bill.id)
              : await File(legacyPath!).readAsBytes();
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_cleanError(error))),
          );
        }
      },
      icon: const Icon(Icons.image_outlined),
    );
  }
}

class _SupplierBillPhotoStore {
  static const _preferencesPrefix = 'supplier_purchase_bill_photo_';

  static Future<String?> getPath(String billId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('$_preferencesPrefix$billId');
  }
}

class _SupplierBillsEmptyState extends StatelessWidget {
  const _SupplierBillsEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 42, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'No supplier bills recorded yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Record an offline supplier invoice to add received stock.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _SupplierBillFormDialog extends StatefulWidget {
  const _SupplierBillFormDialog({required this.api});

  final AdminApiService api;

  @override
  State<_SupplierBillFormDialog> createState() =>
      _SupplierBillFormDialogState();
}

class _SupplierBillFormDialogState extends State<_SupplierBillFormDialog> {
  static const _savedSuppliersKey = 'windows_admin_saved_suppliers_v1';
  final _formKey = GlobalKey<FormState>();
  final _supplierName = TextEditingController();
  final _supplierPhone = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _deliveryPerson = TextEditingController();
  final _notes = TextEditingController();
  final _productSearch = TextEditingController();
  final _lines = <String, _SupplierBillLine>{};
  DateTime _invoiceDate = DateTime.now();
  List<AdminProduct> _searchResults = const [];
  Uint8List? _photoBytes;
  String? _photoName;
  Timer? _searchTimer;
  bool _searching = false;
  bool _saving = false;
  bool _loadingSuppliers = true;
  List<Map<String, String>> _savedSuppliers = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedSuppliers());
  }

  Future<void> _loadSavedSuppliers() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_savedSuppliersKey) ?? const [];
      final suppliers = raw
          .map((entry) {
            final decoded = jsonDecode(entry);
            if (decoded is! Map<String, dynamic>) return null;
            return <String, String>{
              'name': decoded['name']?.toString() ?? '',
              'phone': decoded['phone']?.toString() ?? '',
              'deliveryPerson': decoded['deliveryPerson']?.toString() ?? '',
            };
          })
          .whereType<Map<String, String>>()
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _savedSuppliers = suppliers;
        _loadingSuppliers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _rememberSupplier() async {
    final name = _supplierName.text.trim();
    if (name.isEmpty) return;
    final entry = <String, String>{
      'name': name,
      'phone': _supplierPhone.text.trim(),
      'deliveryPerson': _deliveryPerson.text.trim(),
    };
    final next = [
      entry,
      ..._savedSuppliers.where(
        (supplier) =>
            supplier['name']?.toLowerCase() != name.toLowerCase() ||
            (supplier['phone'] ?? '') != entry['phone'],
      ),
    ].take(50).toList(growable: false);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _savedSuppliersKey,
        next.map((supplier) => jsonEncode(supplier)).toList(growable: false),
      );
      if (mounted) setState(() => _savedSuppliers = next);
    } catch (_) {
      // The purchase bill remains saved even if local convenience storage fails.
    }
  }

  void _selectSavedSupplier(Map<String, String> supplier) {
    setState(() {
      _supplierName.text = supplier['name'] ?? '';
      _supplierPhone.text = supplier['phone'] ?? '';
      _deliveryPerson.text = supplier['deliveryPerson'] ?? '';
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _supplierName.dispose();
    _supplierPhone.dispose();
    _invoiceNumber.dispose();
    _deliveryPerson.dispose();
    _notes.dispose();
    _productSearch.dispose();
    for (final line in _lines.values) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _selectInvoiceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (!mounted || date == null) return;
    setState(() => _invoiceDate = date);
  }

  Future<void> _pickBillPhoto() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (!mounted || files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The selected image could not be read.');
      }
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('Choose a bill photo smaller than 5 MB.');
      }
      final extension = file.extension?.toLowerCase();
      if (!_supportedImageExtension(extension)) {
        throw const FormatException(
          'Choose a JPG, PNG, or WEBP bill photo.',
        );
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = file.name;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _cleanError(error));
    }
  }

  Future<void> _captureBillPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The captured photo could not be read.');
      }
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException(
          'The captured photo is larger than 5 MB. Retake it closer to the bill.',
        );
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = photo.name.isEmpty ? 'supplier-bill.jpg' : photo.name;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _cleanError(error));
    }
  }

  String _imageExtension(String name) => name.split('.').last.toLowerCase();

  bool _supportedImageExtension(String? extension) =>
      const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);

  void _onProductSearchChanged(String value) {
    _searchTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchProducts(value.trim());
    });
  }

  Future<void> _searchProducts(String query) async {
    setState(() => _searching = true);
    try {
      final result = await widget.api.getProducts(
        page: 1,
        pageSize: 20,
        search: query,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = result.products;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _cleanError(error);
      });
    }
  }

  void _addProduct(AdminProduct product) {
    if (_lines.containsKey(product.id)) return;
    setState(() {
      _lines[product.id] = _SupplierBillLine(product: product);
      _productSearch.clear();
      _searchResults = const [];
    });
  }

  void _removeProduct(String productId) {
    setState(() {
      _lines.remove(productId)?.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one product to this bill.');
      return;
    }
    if (_photoBytes == null ||
        _photoName == null ||
        !_supportedImageExtension(_imageExtension(_photoName!))) {
      setState(() => _error = 'Attach a photo of the supplier bill.');
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final line in _lines.values) {
      final quantity = double.tryParse(line.quantity.text.trim());
      final unitCost = double.tryParse(line.unitCost.text.trim());
      if (quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          unitCost == null ||
          !unitCost.isFinite ||
          unitCost < 0) {
        setState(() => _error =
            'Enter a positive received quantity and valid cost for every product.');
        return;
      }
      if (!_isWeightUnit(line.product.unitLabel) &&
          quantity.truncateToDouble() != quantity) {
        setState(() => _error =
            '${line.product.name} uses whole units; enter a whole-number quantity.');
        return;
      }
      items.add({
        'productId': line.product.id,
        'quantity': quantity,
        'unitCost': unitCost,
      });
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bill = await widget.api.createSupplierPurchaseBill({
        'supplierName': _supplierName.text.trim(),
        'supplierPhone': _nullable(_supplierPhone.text),
        'invoiceNumber': _invoiceNumber.text.trim(),
        'invoiceDate': DateTime.utc(
          _invoiceDate.year,
          _invoiceDate.month,
          _invoiceDate.day,
        ).toIso8601String(),
        'deliveryPerson': _nullable(_deliveryPerson.text),
        'notes': _nullable(_notes.text),
        'items': items,
      }, photoBytes: _photoBytes!, photoFileName: _photoName!);
      await _rememberSupplier();
      if (mounted) {
        Navigator.of(context).pop(bill);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _cleanError(error);
      });
    }
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  bool _isWeightUnit(String unitLabel) =>
      RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
          .hasMatch(unitLabel);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: const Text('Record supplier bill'),
      content: SizedBox(
        width: width >= 1050 ? 940 : width * 0.9,
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _supplierName,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / dealer name *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the supplier name.'
                              : null,
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextFormField(
                      controller: _supplierPhone,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Supplier phone',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: TextFormField(
                      controller: _invoiceNumber,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Invoice number *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the invoice number.'
                              : null,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _selectInvoiceDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      'Invoice date · ${DateFormat('d MMM yyyy').format(_invoiceDate)}',
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextFormField(
                      controller: _deliveryPerson,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Delivery person name',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _notes,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                      ),
                    ),
                  ),
                ],
              ),
              if (_savedSuppliers.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedSuppliers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final supplier = _savedSuppliers[index];
                      return ActionChip(
                        avatar: const Icon(Icons.history_rounded, size: 16),
                        label: Text(
                          (supplier['phone'] ?? '').isEmpty
                              ? supplier['name'] ?? ''
                              : '${supplier['name']} · ${supplier['phone']}',
                        ),
                        onPressed: _saving
                            ? null
                            : () => _selectSavedSupplier(supplier),
                      );
                    },
                  ),
                ),
              ] else if (_loadingSuppliers) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (Platform.isAndroid || Platform.isIOS)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _captureBillPhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take bill photo'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickBillPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_photoName == null
                        ? 'Choose photo *'
                        : 'Photo · $_photoName'),
                  ),
                ],
              ),
              if (_photoBytes != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  width: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _productSearch,
                enabled: !_saving,
                onChanged: _onProductSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _searchTimer?.cancel();
                  if (value.trim().isNotEmpty) {
                    _searchProducts(value.trim());
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Add products by name, brand or SKU',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              if (_searching)
                const LinearProgressIndicator(minHeight: 2)
              else if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 116,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final alreadyAdded = _lines.containsKey(product.id);
                      return ListTile(
                        dense: true,
                        title: Text(product.name),
                        subtitle: Text('${product.sku} · ${product.unitLabel}'),
                        trailing: IconButton(
                          tooltip: alreadyAdded ? 'Already added' : 'Add item',
                          onPressed: _saving || alreadyAdded
                              ? null
                              : () => _addProduct(product),
                          icon: Icon(alreadyAdded
                              ? Icons.check_rounded
                              : Icons.add_circle_outline_rounded),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              const AppSectionLabel('Received items · quantity · unit cost'),
              const SizedBox(height: 6),
              Expanded(
                child: _lines.isEmpty
                    ? Center(
                        child: Text(
                          'Search and add the products from this invoice.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : Scrollbar(
                        child: ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _lines.length,
                          itemBuilder: (context, index) {
                            final line = _lines.values.elementAt(index);
                            return _SupplierBillLineEditor(
                              line: line,
                              enabled: !_saving,
                              onChanged: () => setState(() {}),
                              onRemove: () => _removeProduct(line.product.id),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Bill total  ${_money(_totalCost)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorText,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.inventory_2_outlined),
          label: const Text('Save bill & add stock'),
        ),
      ],
    );
  }

  double get _totalCost => _lines.values.fold<double>(
        0,
        (total, line) {
          final quantity = double.tryParse(line.quantity.text.trim()) ?? 0;
          final cost = double.tryParse(line.unitCost.text.trim()) ?? 0;
          return total + quantity * cost;
        },
      );

  String _money(double value) =>
      NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2).format(value);
}

class _SupplierBillLine {
  _SupplierBillLine({required this.product})
      : quantity = TextEditingController(text: '1'),
        unitCost = TextEditingController(text: '0');

  final AdminProduct product;
  final TextEditingController quantity;
  final TextEditingController unitCost;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class _SupplierBillLineEditor extends StatelessWidget {
  const _SupplierBillLineEditor({
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final _SupplierBillLine line;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.product.name} · ${line.product.unitLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove product',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: line.quantity,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Received quantity',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: line.unitCost,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Cost per unit (Rs)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
