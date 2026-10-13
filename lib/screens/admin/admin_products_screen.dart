import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/media.dart';
import '../../core/product_sku.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminProductsScreen extends StatefulWidget {
  final ApiService api;

  const AdminProductsScreen({super.key, required this.api});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminCategory> _categories = [];
  AdminProductPage? _productPage;
  String? _error;
  bool _loading = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminApi.getCategories(),
        _adminApi.getProducts(page: page),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<AdminCategory>;
        _productPage = results[1] as AdminProductPage;
        _page = page;
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

  Future<void> _editProduct([AdminProduct? product]) async {
    if (_categories.where((category) => category.isActive).isEmpty) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        api: _adminApi,
        categories: _categories,
        product: product,
      ),
    );
    if (saved == true) _load(page: _page);
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store catalog',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      _productPage == null
                          ? 'Manage products and stock.'
                          : '${_productPage!.pagination.total} products in the catalog',
                      style: TextStyle(
                          color: AppConstants.textMuted, fontSize: 12),
                    ),
                  ],
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
                label: const Text('Add'),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Notice(message: _error!, icon: Icons.warning_amber_rounded),
          ],
          const SizedBox(height: 16),
          if (products.isEmpty && !_loading)
            const _EmptyProducts()
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

  const _ProductFormDialog({
    required this.api,
    required this.categories,
    this.product,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _skuController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _originController;
  late final TextEditingController _unitAmountController;
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _wholesaleMinimumController;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _removeCurrentImage = false;
  bool _isWholesale = false;
  String? _categoryId;
  String _unitType = 'pack';
  bool _saving = false;
  String? _error;
  String _weightUnit = 'g';
  String _volumeUnit = 'ml';

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
    _nameController = TextEditingController(text: product?.name ?? '');
    _brandController = TextEditingController(text: product?.brand ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _priceController = TextEditingController(
        text: product?.price == null ? '' : product!.price.toStringAsFixed(2));
    _originalPriceController = TextEditingController(
      text: product?.originalPrice?.toStringAsFixed(2) ?? '',
    );
    _stockController =
        TextEditingController(text: product?.stock.toString() ?? '0');
    _descriptionController =
        TextEditingController(text: product?.description ?? '');
    _originController = TextEditingController(text: product?.origin ?? '');
    final unitParts =
        RegExp(r'^([\d.]+)\s*(.*)$').firstMatch(product?.unitLabel ?? '');
    _unitAmountController = TextEditingController(
      text: unitParts?.group(1) ?? '1',
    );
    _wholesalePriceController = TextEditingController(
      text: product?.wholesalePrice?.toStringAsFixed(2) ?? '',
    );
    _wholesaleMinimumController = TextEditingController(
      text: product?.wholesaleMinimumQuantity.toString() ?? '1',
    );
    _isWholesale = product?.isWholesale ?? false;
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
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _originController.dispose();
    _unitAmountController.dispose();
    _wholesalePriceController.dispose();
    _wholesaleMinimumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
      'categoryId': _categoryId,
      'imageUrl': _removeCurrentImage ? null : widget.product?.imageUrl,
      'brand': _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'originalPrice': double.tryParse(_originalPriceController.text.trim()),
      'isWholesale': _isWholesale,
      'wholesalePrice': _isWholesale
          ? double.tryParse(_wholesalePriceController.text.trim())
          : null,
      'wholesaleMinimumQuantity':
          int.tryParse(_wholesaleMinimumController.text.trim()) ?? 1,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'origin': _originController.text.trim().isEmpty
          ? null
          : _originController.text.trim(),
      'unitLabel': '${_unitAmountController.text.trim()} $_selectedUnitSuffix',
    };
    final stock = int.parse(_stockController.text.trim());

    try {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Add product' : 'Edit product'),
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
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 12,
                    ),
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
                          borderRadius: BorderRadius.circular(12),
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
                                    fit: BoxFit.cover,
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
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Stock quantity'),
                        validator: (value) {
                          final stock = int.tryParse(value?.trim() ?? '');
                          if (stock == null || stock < 0) {
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
                    labelText: 'Original price (optional)',
                    helperText: 'Enter this only when offering a discount.',
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offer this product wholesale'),
                  subtitle: const Text(
                    'Show it in Wholesale with its own bulk price and minimum quantity.',
                  ),
                  value: _isWholesale,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isWholesale = value),
                ),
                if (_isWholesale) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _wholesalePriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Bulk price (Rs.)',
                          ),
                          validator: (value) {
                            final price = double.tryParse(value?.trim() ?? '');
                            if (price == null ||
                                !price.isFinite ||
                                price <= 0) {
                              return 'Enter a bulk price above 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _wholesaleMinimumController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum quantity',
                          ),
                          validator: (value) {
                            final quantity = int.tryParse(value?.trim() ?? '');
                            if (quantity == null ||
                                quantity < 1 ||
                                quantity > 10000) {
                              return 'Enter a quantity from 1 to 10,000';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Low-stock threshold is not present in the current inventory schema.',
                    style:
                        TextStyle(fontSize: 11, color: AppConstants.textMuted),
                  ),
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
              : const Text('Save product'),
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
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
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
                  style: TextStyle(fontSize: 11, color: AppConstants.textMuted),
                ),
                if (product.brand?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.brand!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppConstants.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                        '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    if (product.originalPrice != null &&
                        product.originalPrice! > product.price) ...[
                      const SizedBox(width: 7),
                      Text(
                        '${AppConstants.currencySymbol}${product.originalPrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppConstants.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Text('${product.unitLabel} · stock ${product.stock}',
                        style: TextStyle(
                            fontSize: 11, color: AppConstants.textMuted)),
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
                      ? Colors.redAccent
                      : AppConstants.primary,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 54,
        height: 54,
        color: AppConstants.primaryLight,
        child: imageUrl.isEmpty
            ? const Icon(Icons.inventory_2_outlined,
                color: AppConstants.primary)
            : Image.network(
                optimizedProductImageUrl(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppConstants.primary),
              ),
      ),
    );
  }
}

class _ProductStatus extends StatelessWidget {
  final bool active;

  const _ProductStatus({required this.active});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFECFDF5) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF047857) : AppConstants.textMuted),
        ),
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
              style: TextStyle(color: AppConstants.textMuted)),
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
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppConstants.textMuted),
              const SizedBox(height: 12),
              const Text('Products unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConstants.textMuted)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: AppConstants.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppConstants.borderLight)),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 34, color: AppConstants.textMuted),
            const SizedBox(height: 10),
            const Text('No products found',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('Products from your catalog will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppConstants.textMuted)),
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
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(11)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9A3412)))),
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
