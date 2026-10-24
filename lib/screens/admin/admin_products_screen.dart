import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/media.dart';
import '../../core/product_sku.dart';
import '../../models/admin_models.dart';
import '../../models/scanned_product_barcode.dart';
import '../../screens/admin/barcode_scanner_screen.dart';
import '../../providers/product_provider.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/store_animation.dart';

class AdminProductsScreen extends StatefulWidget {
  final ApiService api;
  final bool vendingOnly;

  const AdminProductsScreen({
    super.key,
    required this.api,
    this.vendingOnly = false,
  });

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _searchController = TextEditingController();
  List<AdminCategory> _categories = [];
  AdminProductPage? _productPage;
  String? _error;
  bool _loading = true;
  int _page = 1;
  int _loadRequest = 0;
  Timer? _searchTimer;
  bool _observedTabVisibility = false;
  bool _wasTabVisible = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_observedTabVisibility && isVisible && !_wasTabVisible) {
      _load(page: _page);
    }
    _observedTabVisibility = true;
    _wasTabVisible = isVisible;
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminApi.getCategories(),
        _adminApi.getProducts(
          page: page,
          search: _searchController.text,
          vendingDrink: widget.vendingOnly ? true : null,
        ),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _categories = results[0] as List<AdminCategory>;
        _productPage = results[1] as AdminProductPage;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
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

  Future<void> _editProduct([AdminProduct? product]) async {
    if (_categories.where((category) => category.isActive).isEmpty) return;
    final productProvider =
        Provider.of<ProductProvider?>(context, listen: false);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        api: _adminApi,
        categories: _categories,
        product: product,
        vendingOnly: widget.vendingOnly,
        onExistingProduct: (existing) {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _editProduct(existing);
          });
        },
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      _load(page: _page);
      await productProvider?.loadCatalog();
    }
  }

  Future<void> _setActive(AdminProduct product, bool isActive) async {
    if (!isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove product from storefront?'),
          content: Text(
            '“${product.name}” will no longer be available to customers. '
            'Its record and order history will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove product'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _adminApi.setProductActive(product.id, isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? '${product.name} restored to the storefront.'
                : '${product.name} removed from the storefront.',
          ),
        ),
      );
      _load(page: _page);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _productPage?.products ?? const <AdminProduct>[];
    if (_loading && _productPage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _productPage == null) {
      return _ProductsError(
          message: _error!, onRetry: () => _load(page: _page));
    }

    return RefreshIndicator(
      onRefresh: () => _load(page: _page),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _productPage == null
                      ? widget.vendingOnly
                          ? 'Manage drinks shown in the customer drinks menu.'
                          : 'Manage products and stock.'
                      : widget.vendingOnly
                          ? '${_productPage!.pagination.total} drinks'
                          : '${_productPage!.pagination.total} products in the catalog',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh products',
                onPressed: _loading ? null : () => _load(page: _page),
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: _categories.any((category) => category.isActive)
                    ? () => _editProduct()
                    : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(widget.vendingOnly ? 'Add drink' : 'Add product'),
              ),
            ],
          ),
          if (_categories.isEmpty && !_loading) ...[
            const SizedBox(height: 12),
            const _Notice(
              message: 'Create an active category before adding products.',
              icon: Icons.info_outline_rounded,
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              _searchTimer?.cancel();
              _load(page: 1);
            },
            decoration: InputDecoration(
              hintText: widget.vendingOnly
                  ? 'Search drinks by name, brand or SKU'
                  : 'Search products by name, brand or SKU',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.text.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        _load(page: 1);
                      },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Notice(message: _error!, icon: Icons.warning_amber_rounded),
          ],
          const SizedBox(height: 16),
          if (products.isEmpty && !_loading)
            _EmptyProducts(vendingOnly: widget.vendingOnly)
          else
            ...products.map(
              (product) => _ProductCard(
                product: product,
                onEdit: () => _editProduct(product),
                onSetActive: () => _setActive(product, !product.isActive),
              ),
            ),
          if (_loading && _productPage != null)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_productPage != null &&
              _productPage!.pagination.total >
                  _productPage!.pagination.pageSize)
            _PaginationBar(
              pagination: _productPage!.pagination,
              onPage: (page) => _load(page: page),
            ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final AdminApiService api;
  final List<AdminCategory> categories;
  final AdminProduct? product;
  final bool vendingOnly;
  final ValueChanged<AdminProduct>? onExistingProduct;

  const _ProductFormDialog({
    required this.api,
    required this.categories,
    this.product,
    this.vendingOnly = false,
    this.onExistingProduct,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _lotNumberController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _originController;
  late final TextEditingController _unitAmountController;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  final List<_PendingProductImage> _pickedGalleryImages = [];
  late List<String> _galleryImageUrls;
  bool _removeCurrentImage = false;
  String? _categoryId;
  String _unitType = 'pack';
  bool _saving = false;
  late bool _isVendingDrink;
  String? _vendingSection;
  String? _error;
  String _weightUnit = 'g';
  String _volumeUnit = 'ml';
  late bool _isBestSeller;
  DateTime? _manufacturedAt;
  DateTime? _expiresAt;
  bool _noExpiry = false;
  bool _lookingUpBarcode = false;
  String? _lookupImageUrl;

  List<AdminCategory> get _availableCategories {
    final active =
        widget.categories.where((category) => category.isActive).toList();
    final productCategory = widget.product?.categoryId;
    if (productCategory != null &&
        productCategory.isNotEmpty &&
        !active.any((category) => category.id == productCategory)) {
      final existing =
          widget.categories.where((category) => category.id == productCategory);
      if (existing.isNotEmpty) active.add(existing.first);
    }
    return active;
  }

  String get _selectedUnitSuffix {
    if (_isBiscuitOrCookie) {
      return _unitType == 'count' ? 'pcs' : 'pack';
    }
    return switch (_unitType) {
      'weight' => _weightUnit,
      'volume' => _volumeUnit,
      'count' => 'pcs',
      _ => 'pack',
    };
  }

  bool get _isBiscuitOrCookie {
    final matchingCategories = _availableCategories
        .where((item) => item.id == _categoryId)
        .map((item) => item.name)
        .toList(growable: false);
    final category = matchingCategories.isEmpty
        ? ''
        : matchingCategories.first.toLowerCase();
    final name = _nameController.text.toLowerCase();
    return RegExp(r'\b(biscuit|biscuits|cookie|cookies)\b')
        .hasMatch('$name $category');
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _galleryImageUrls = List.of(product?.imageUrls ?? const []);
    _isVendingDrink = product?.isVendingDrink ?? widget.vendingOnly;
    _vendingSection = product?.vendingSection;
    _isBestSeller = product?.isBestSeller ?? false;
    _nameController = TextEditingController(text: product?.name ?? '');
    _brandController = TextEditingController(text: product?.brand ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _lotNumberController = TextEditingController();
    _priceController = TextEditingController(
        text: product?.price == null ? '' : product!.price.toStringAsFixed(2));
    _originalPriceController = TextEditingController(
      text: product?.originalPrice?.toStringAsFixed(2) ?? '',
    );
    _stockController = TextEditingController(
      text: product == null
          ? '0'
          : (product.weightStockKg ?? product.stock.toDouble())
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    _lowStockThresholdController = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '10',
    );
    _descriptionController =
        TextEditingController(text: product?.description ?? '');
    _originController = TextEditingController(text: product?.origin ?? '');
    final unitParts =
        RegExp(r'^([\d.]+)\s*(.*)$').firstMatch(product?.unitLabel ?? '');
    _unitAmountController = TextEditingController(
      text: unitParts?.group(1) ?? '1',
    );
    final savedUnit = unitParts?.group(2)?.toLowerCase();
    _unitType = switch (savedUnit) {
      'kg' || 'g' => 'weight',
      'l' || 'ml' => 'volume',
      'pc' || 'pcs' => 'count',
      'pack' => 'pack',
      _ => 'pack',
    };
    if (savedUnit == 'kg' || savedUnit == 'g') _weightUnit = savedUnit!;
    if (savedUnit == 'l' || savedUnit == 'ml') _volumeUnit = savedUnit!;
    _categoryId = product?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _lotNumberController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _descriptionController.dispose();
    _originController.dispose();
    _unitAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stock = double.parse(_stockController.text.trim());
    if (widget.product == null &&
        stock > 0 &&
        (_manufacturedAt == null ||
            (!_noExpiry && _expiresAt == null) ||
            (_noExpiry && _expiresAt != null) ||
            (_expiresAt != null && !_expiresAt!.isAfter(_manufacturedAt!)))) {
      setState(() => _error =
          'Enter a valid manufacture date and a later expiry date, or confirm that this product has no expiry.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final category =
        _availableCategories.firstWhere((item) => item.id == _categoryId);
    final enteredSku = _skuController.text.trim().toUpperCase();
    final sku = enteredSku.isEmpty
        ? generateStoreSku(
            categorySlug: category.slug,
            productName: name,
          )
        : enteredSku;
    final data = <String, dynamic>{
      'name': name,
      'slug': _slugify(name).isEmpty
          ? (_slugify(_skuController.text).isEmpty
              ? 'product-${DateTime.now().millisecondsSinceEpoch}'
              : _slugify(_skuController.text))
          : _slugify(name),
      'sku': sku,
      'barcode': _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      'categoryId': _categoryId,
      'imageUrl': _removeCurrentImage
          ? null
          : widget.product?.imageUrl ?? _lookupImageUrl,
      'imageUrls': _galleryImageUrls,
      'brand': _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'originalPrice': double.tryParse(_originalPriceController.text.trim()),
      'lowStockThreshold': int.parse(_lowStockThresholdController.text.trim()),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'origin': _originController.text.trim().isEmpty
          ? null
          : _originController.text.trim(),
      'unitLabel': '${_unitAmountController.text.trim()} $_selectedUnitSuffix',
      'isVendingDrink': _isVendingDrink,
      'vendingSection': _isVendingDrink ? _vendingSection : null,
      if (widget.vendingOnly) 'isBestSeller': _isBestSeller,
    };
    if (widget.product == null && stock > 0) {
      data['initialBatch'] = {
        'lotNumber': _lotNumberController.text.trim().isEmpty
            ? null
            : _lotNumberController.text.trim(),
        'manufacturedAt': _dateAsUtc(_manufacturedAt!).toIso8601String(),
        'expiresAt':
            _noExpiry ? null : _dateAsUtc(_expiresAt!).toIso8601String(),
        'noExpiry': _noExpiry,
      };
    }

    try {
      final uploadedGalleryUrls = await Future.wait(
        _pickedGalleryImages.map(
          (image) => widget.api.uploadProductImage(image.bytes, image.name),
        ),
      );
      data['imageUrls'] = [..._galleryImageUrls, ...uploadedGalleryUrls];
      if (widget.product == null) {
        await widget.api.createProduct(
          data,
          stock,
          imageBytes: _pickedImageBytes,
          imageName: _pickedImageName,
        );
      } else {
        await widget.api.updateProduct(
          widget.product!.id,
          data,
          stock,
          imageBytes: _pickedImageBytes,
          imageName: _pickedImageName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isEmpty) return;
    final file = files.first;
    final size = await file.length();
    if (size == null) {
      setState(
          () => _error = 'Unable to read that image. Choose another file.');
      return;
    }

    if (size > 5 * 1024 * 1024) {
      setState(() => _error = 'Choose an image smaller than 5 MB.');
      return;
    }
    final extension = file.extension?.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      setState(() => _error = 'Choose a JPEG, PNG, or WebP image.');
      return;
    }
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name;
      _removeCurrentImage = false;
      _error = null;
    });
  }

  Future<void> _pickGalleryImages() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final pending = <_PendingProductImage>[];
    for (final file in files) {
      final size = await file.length();
      final extension = file.name.split('.').last.toLowerCase();
      if (size == null ||
          size > 5 * 1024 * 1024 ||
          !{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        if (!mounted) return;
        setState(() {
          _error = 'Photos must be JPEG, PNG, or WebP files under 5 MB each.';
        });
        return;
      }

      pending.add(
        _PendingProductImage(
          bytes: await file.readAsBytes(),
          name: file.name,
        ),
      );
    }
    if (_galleryImageUrls.length +
            _pickedGalleryImages.length +
            pending.length >
        8) {
      if (!mounted) return;
      setState(() => _error = 'A product can have up to 8 additional photos.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _pickedGalleryImages.addAll(pending);
      _error = null;
    });
  }

  DateTime _dateAsUtc(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  String _formatBatchDate(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  Future<void> _scanBarcode() async {
    final scannedBarcode =
        await Navigator.of(context).push<ScannedProductBarcode>(
      MaterialPageRoute<ScannedProductBarcode>(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    if (!mounted || scannedBarcode == null) return;
    _barcodeController.text = scannedBarcode.value;
    if (scannedBarcode.manufacturedAt != null ||
        scannedBarcode.expiresAt != null) {
      setState(() {
        _manufacturedAt = scannedBarcode.manufacturedAt ?? _manufacturedAt;
        _expiresAt = scannedBarcode.expiresAt ?? _expiresAt;
        _noExpiry = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GS1 dates were detected. Verify both dates on the package before saving.',
          ),
        ),
      );
    }
    await _lookupBarcode();
  }

  Future<void> _lookupBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (!RegExp(r'^[A-Za-z0-9._:/+-]{4,128}$').hasMatch(barcode)) {
      setState(() => _error = 'Enter a valid barcode or product code.');
      return;
    }
    setState(() {
      _lookingUpBarcode = true;
      _error = null;
    });
    try {
      final result = await widget.api.lookupProductBarcode(barcode);
      if (!mounted) return;
      final source = result['source'] as String;
      final rawProduct = result['product'];
      if (source == 'catalog' && rawProduct is Map<String, dynamic>) {
        final existing = AdminProduct.fromJson(rawProduct);
        if (existing.id == widget.product?.id) {
          setState(() => _lookingUpBarcode = false);
          return;
        }
        setState(() => _lookingUpBarcode = false);
        final editExisting = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Product already exists'),
            content: Text(
              '${existing.name} already uses this barcode. Edit that product instead of creating a duplicate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep scanning'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Edit product'),
              ),
            ],
          ),
        );
        if (editExisting == true) {
          widget.onExistingProduct?.call(existing);
        }
        return;
      }
      if (rawProduct is Map<String, dynamic>) {
        final productName = rawProduct['name']?.toString().trim();
        final brand = rawProduct['brand']?.toString().trim();
        final description = rawProduct['description']?.toString().trim();
        final imageUrl = rawProduct['imageUrl']?.toString().trim();
        final unitLabel = rawProduct['unitLabel']?.toString().trim();
        setState(() {
          if (_nameController.text.trim().isEmpty &&
              productName != null &&
              productName.isNotEmpty) {
            _nameController.text = productName;
          }
          if (_brandController.text.trim().isEmpty &&
              brand != null &&
              brand.isNotEmpty) {
            _brandController.text = brand;
          }
          if (_descriptionController.text.trim().isEmpty &&
              description != null &&
              description.isNotEmpty) {
            _descriptionController.text = description;
          }
          final parsedImage = imageUrl == null ? null : Uri.tryParse(imageUrl);
          if (_lookupImageUrl == null &&
              parsedImage != null &&
              (parsedImage.scheme == 'https' || parsedImage.scheme == 'http') &&
              parsedImage.host.isNotEmpty) {
            _lookupImageUrl = imageUrl;
          }
          if (unitLabel != null && unitLabel.isNotEmpty) {
            _applyLookupUnit(unitLabel);
          }
          _lookingUpBarcode = false;
        });
        return;
      }
      setState(() => _lookingUpBarcode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No product details were found. Enter the details manually; the barcode will be saved for future scans.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lookingUpBarcode = false;
        _error = _cleanError(error);
      });
    }
  }

  void _applyLookupUnit(String unitLabel) {
    final match = RegExp(
      r'^\s*([\d.]+)\s*(kg|g|ml|l|pcs?|pack)\b',
      caseSensitive: false,
    ).firstMatch(unitLabel);
    if (match == null) return;
    final amount = double.tryParse(match.group(1) ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) return;
    final unit = match.group(2)!.toLowerCase();
    _unitAmountController.text = match.group(1)!;
    if (unit == 'kg' || unit == 'g') {
      _unitType = 'weight';
      _weightUnit = unit;
    } else if (unit == 'ml' || unit == 'l') {
      _unitType = 'volume';
      _volumeUnit = unit;
    } else if (unit.startsWith('pc')) {
      _unitType = 'count';
    } else {
      _unitType = 'pack';
    }
  }

  Future<void> _chooseBatchDate({
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
      _error = null;
    });
    onSelected?.call(date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.vendingOnly
            ? widget.product == null
                ? 'Add drink'
                : 'Edit drink'
            : widget.product == null
                ? 'Add product'
                : 'Edit product',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _brandController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Brand name'),
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _skuController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'SKU (optional)',
                    helperText:
                        'Unique store stock code, not a universal barcode. '
                        'Leave blank to generate one.',
                  ),
                  validator: (value) {
                    final sku = value?.trim() ?? '';
                    if (sku.isNotEmpty &&
                        !RegExp(r'^[A-Z0-9]+(?:-[A-Z0-9]+)*$')
                            .hasMatch(sku.toUpperCase())) {
                      return 'Use letters, numbers, and hyphens only.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _barcodeController,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _lookupBarcode(),
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    hintText: 'EAN, UPC, Code 128 or QR product code',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Scan barcode with camera',
                          onPressed: _saving ? null : _scanBarcode,
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                        IconButton(
                          tooltip: 'Look up product',
                          onPressed: _saving || _lookingUpBarcode
                              ? null
                              : _lookupBarcode,
                          icon: _lookingUpBarcode
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                        ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    final barcode = value?.trim() ?? '';
                    if (barcode.isNotEmpty &&
                        !RegExp(r'^[A-Za-z0-9._:/+-]{4,128}$')
                            .hasMatch(barcode)) {
                      return 'Use 4-128 letters, numbers, or standard code separators.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  initialValue: _availableCategories
                          .any((category) => category.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _availableCategories
                      .map((category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Choose a category' : null,
                ),
                const SizedBox(height: 11),
                if (_isBiscuitOrCookie)
                  Text(
                    'Biscuits and cookies are sold by pack or piece, not by weight or volume.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _unitType,
                    decoration: const InputDecoration(labelText: 'Sold by'),
                    items: const [
                      DropdownMenuItem(value: 'weight', child: Text('Weight')),
                      DropdownMenuItem(value: 'volume', child: Text('Volume')),
                      DropdownMenuItem(value: 'count', child: Text('Pieces')),
                      DropdownMenuItem(value: 'pack', child: Text('Pack')),
                    ],
                    onChanged: (value) =>
                        setState(() => _unitType = value ?? _unitType),
                  ),
                const SizedBox(height: 8),
                if (widget.vendingOnly)
                  DropdownButtonFormField<String>(
                    initialValue: _vendingSection,
                    decoration: const InputDecoration(
                      labelText: 'Drink menu section',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SODA', child: Text('Soda')),
                      DropdownMenuItem(
                        value: 'TEA_COFFEE',
                        child: Text('Tea & Coffee'),
                      ),
                      DropdownMenuItem(
                        value: 'ENERGY',
                        child: Text('Energy drink'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _vendingSection = value),
                    validator: (value) =>
                        value == null ? 'Choose a drink menu section.' : null,
                  ),
                if (widget.vendingOnly)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show as featured drink'),
                    subtitle: const Text(
                      'Display this drink in the large card at the top of the menu.',
                    ),
                    value: _isBestSeller,
                    onChanged: (value) => setState(() => _isBestSeller = value),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unitAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Pack/quantity size',
                          hintText: 'e.g. 500',
                        ),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');
                          if (amount == null ||
                              !amount.isFinite ||
                              amount <= 0) {
                            return 'Enter a quantity above 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${_unitType}_${_isBiscuitOrCookie ? 'biscuit' : 'other'}',
                        ),
                        initialValue: _selectedUnitSuffix,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: (_isBiscuitOrCookie
                                ? const ['pack', 'pcs']
                                : switch (_unitType) {
                                    'weight' => const ['g', 'kg'],
                                    'volume' => const ['ml', 'l'],
                                    'count' => const ['pcs'],
                                    _ => const ['pack'],
                                  })
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            if (value == 'g' || value == 'kg') {
                              _unitType = 'weight';
                              _weightUnit = value;
                            } else if (value == 'ml' || value == 'l') {
                              _unitType = 'volume';
                              _volumeUnit = value;
                            } else {
                              _unitType = value == 'pcs' ? 'count' : 'pack';
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.product == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opening batch dates are required when adding starting stock.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lotNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Batch / lot number (optional)',
                    ),
                  ),
                  FormField<DateTime>(
                    initialValue: _manufacturedAt,
                    validator: (value) {
                      final needsBatch =
                          (double.tryParse(_stockController.text.trim()) ?? 0) >
                              0;
                      if (needsBatch && value == null) {
                        return 'Choose a manufacture date.';
                      }
                      if (value != null &&
                          DateTime(value.year, value.month, value.day)
                              .isAfter(DateTime.now())) {
                        return 'Manufacture date cannot be in the future.';
                      }
                      return null;
                    },
                    builder: (field) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.factory_outlined),
                      title: Text(
                        _manufacturedAt == null
                            ? 'Manufacture date (MFG)'
                            : 'MFG · ${_formatBatchDate(_manufacturedAt!)}',
                      ),
                      subtitle: field.errorText == null
                          ? null
                          : Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: _saving
                          ? null
                          : () => _chooseBatchDate(
                                manufactureDate: true,
                                onSelected: field.didChange,
                              ),
                    ),
                  ),
                  FormField<DateTime>(
                    initialValue: _expiresAt,
                    validator: (value) {
                      final needsBatch =
                          (double.tryParse(_stockController.text.trim()) ?? 0) >
                              0;
                      if (!needsBatch || _noExpiry) return null;
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
                      title: Text(
                        _noExpiry
                            ? 'No expiry date confirmed'
                            : _expiresAt == null
                                ? 'Expiry date (EXP)'
                                : 'EXP · ${_formatBatchDate(_expiresAt!)}',
                      ),
                      subtitle: field.errorText == null
                          ? null
                          : Text(
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
                          : () => _chooseBatchDate(
                                manufactureDate: false,
                                onSelected: field.didChange,
                              ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This product does not expire'),
                    value: _noExpiry,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                              _noExpiry = value ?? false;
                              if (_noExpiry) _expiresAt = null;
                            }),
                  ),
                ],
                const SizedBox(height: 11),
                TextFormField(
                  controller: _lowStockThresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Low-stock alert threshold',
                    helperText:
                        'Show in Restock when available stock reaches this amount.',
                  ),
                  validator: (value) {
                    final threshold = int.tryParse(value?.trim() ?? '');
                    if (threshold == null ||
                        threshold < 1 ||
                        threshold > 100000) {
                      return 'Enter a whole number from 1 to 100,000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_pickedImageBytes != null ||
                            (widget.product?.imageUrl != null &&
                                !_removeCurrentImage)
                        ? 'Change product image'
                        : 'Choose product image'),
                  ),
                ),
                if (_pickedImageBytes != null ||
                    (widget.product?.imageUrl != null && !_removeCurrentImage))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.brand),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: _pickedImageBytes != null
                                ? Image.memory(
                                    _pickedImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    optimizedProductImageUrl(
                                      widget.product!.imageUrl!,
                                    ),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickedImageName ?? 'Current product image',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove product image',
                          onPressed: () => setState(() {
                            _pickedImageBytes = null;
                            _pickedImageName = null;
                            _removeCurrentImage = true;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickGalleryImages,
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text('Add product photos'),
                  ),
                ),
                if (_galleryImageUrls.isNotEmpty ||
                    _pickedGalleryImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var index = 0;
                            index < _galleryImageUrls.length;
                            index++)
                          _GalleryImagePreview(
                            imageUrl: _galleryImageUrls[index],
                            onRemove: _saving
                                ? null
                                : () => setState(
                                      () => _galleryImageUrls.removeAt(index),
                                    ),
                          ),
                        for (var index = 0;
                            index < _pickedGalleryImages.length;
                            index++)
                          _GalleryImagePreview(
                            imageBytes: _pickedGalleryImages[index].bytes,
                            onRemove: _saving
                                ? null
                                : () => setState(
                                      () =>
                                          _pickedGalleryImages.removeAt(index),
                                    ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Price (Rs.)'),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          if (price == null || !price.isFinite || price <= 0) {
                            return 'Enter a price above 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _unitType == 'weight'
                              ? 'Stock quantity (kg)'
                              : 'Stock quantity',
                        ),
                        validator: (value) {
                          final stock = double.tryParse(value?.trim() ?? '');
                          if (stock == null || !stock.isFinite || stock < 0) {
                            return 'Enter 0 or more';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _originalPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Before price / MRP (optional)',
                    helperText:
                        'Shown crossed out beside the sale price on featured cards.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final original = double.tryParse(text);
                    final price = double.tryParse(_priceController.text.trim());
                    if (original == null ||
                        !original.isFinite ||
                        original <= (price ?? 0)) {
                      return 'Original price must be higher than sale price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Product description'),
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _originController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Country/region of origin'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Notice(message: _error!, icon: Icons.warning_amber_rounded),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.vendingOnly ? 'Save drink' : 'Save product'),
        ),
      ],
    );
  }
}

class _PendingProductImage {
  const _PendingProductImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class _GalleryImagePreview extends StatelessWidget {
  const _GalleryImagePreview({
    this.imageUrl,
    this.imageBytes,
    required this.onRemove,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.thumbnail),
          child: SizedBox(
            width: 68,
            height: 68,
            child: imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.cover)
                : Image.network(
                    optimizedProductImageUrl(imageUrl ?? ''),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filledTonal(
            tooltip: 'Remove photo',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final AdminProduct product;
  final VoidCallback onEdit;
  final VoidCallback onSetActive;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 6),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          _ProductImage(url: product.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 5),
                    _ProductStatus(active: product.isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.categoryName.isEmpty
                      ? product.sku
                      : '${product.categoryName} · ${product.sku}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (product.brand?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.brand!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (product.originalPrice != null &&
                        product.originalPrice! > product.price)
                      Text(
                        '${AppConstants.currencySymbol}${product.originalPrice!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                      ),
                    Text(
                      '${product.unitLabel} · stock '
                      '${product.weightStockKg?.toStringAsFixed(3) ?? product.stock}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: product.isActive
                    ? 'Remove product from storefront'
                    : 'Restore product to storefront',
                onPressed: onSetActive,
                icon: Icon(
                  product.isActive
                      ? Icons.delete_outline_rounded
                      : Icons.restore_rounded,
                  color: product.isActive
                      ? AppColors.errorText
                      : AppColors.primary,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Product actions',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;

  const _ProductImage({this.url});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.thumbnail),
      child: Container(
        width: 42,
        height: 42,
        color: AppColors.thumbnailBlue,
        child: imageUrl.isEmpty
            ? const Icon(Icons.inventory_2_outlined, color: AppColors.primary)
            : Image.network(
                optimizedProductImageUrl(imageUrl),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.primary),
              ),
      ),
    );
  }
}

class _ProductStatus extends StatelessWidget {
  final bool active;

  const _ProductStatus({required this.active});

  @override
  Widget build(BuildContext context) => AppStatusPill(
        active ? 'Active' : 'Inactive',
        variant: active ? AppStatusVariant.success : AppStatusVariant.neutral,
      );
}

class _PaginationBar extends StatelessWidget {
  final AdminPagination pagination;
  final ValueChanged<int> onPage;

  const _PaginationBar({required this.pagination, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final pages = (pagination.total / pagination.pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed:
                pagination.page > 1 ? () => onPage(pagination.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${pagination.page} of $pages',
              style: const TextStyle(color: AppColors.muted)),
          IconButton(
            tooltip: 'Next page',
            onPressed: pagination.page < pages
                ? () => onPage(pagination.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ProductsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProductsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'Products unavailable',
        message: message,
        retryLabel: 'Try again',
        onRetry: onRetry,
      );
}

class _EmptyProducts extends StatelessWidget {
  final bool vendingOnly;

  const _EmptyProducts({this.vendingOnly = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              offset: Offset(0, 6),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
                vendingOnly
                    ? Icons.local_drink_outlined
                    : Icons.inventory_2_outlined,
                size: 34,
                color: AppColors.muted),
            const SizedBox(height: 10),
            Text(vendingOnly ? 'No drinks yet' : 'No products found',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
                vendingOnly
                    ? 'Add a drink to list it in the customer drinks menu.'
                    : 'Products from your catalog will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  final String message;
  final IconData icon;

  const _Notice({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.warningPill,
          borderRadius: BorderRadius.circular(AppRadii.row),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.warningText),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              message,
              style: const TextStyle(color: AppColors.warningText),
            )),
          ],
        ),
      );
}

String _slugify(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
