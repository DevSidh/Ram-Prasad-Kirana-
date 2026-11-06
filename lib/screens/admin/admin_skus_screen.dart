import '../../widgets/billing_localized_widgets.dart';
import '../../widgets/product_thumbnail.dart';
import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/store_animation.dart';

class AdminSkusScreen extends StatefulWidget {
  final ApiService api;

  const AdminSkusScreen({super.key, required this.api});

  @override
  State<AdminSkusScreen> createState() => _AdminSkusScreenState();
}

class _AdminSkusScreenState extends State<AdminSkusScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminProduct> _products = [];
  Map<String, TextEditingController> _skuControllers = {};
  bool _loading = true;
  int _loadRequest = 0;
  String? _error;
  String? _savingId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_savingId != null) return;
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _adminApi.getAllProducts();
      if (!mounted || request != _loadRequest) return;
      for (final controller in _skuControllers.values) {
        controller.dispose();
      }
      setState(() {
        _products = products;
        _skuControllers = {
          for (final product in products)
            product.id: TextEditingController(text: product.sku),
        };
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

  Future<void> _saveSku(AdminProduct product) async {
    if (_loading || _savingId != null) return;
    final controller = _skuControllers[product.id];
    if (controller == null) return;
    final sku = controller.text.trim();
    if (sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BillingText('SKU cannot be empty.')),
      );
      return;
    }
    if (sku == product.sku) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BillingText('This SKU is already up to date.')),
      );
      return;
    }

    setState(() => _savingId = product.id);
    try {
      await _adminApi.updateProductSku(product.id, sku);
      if (!mounted) return;
      setState(() {
        _products = _products
            .map((item) =>
                item.id == product.id ? item.copyWith(sku: sku) : item)
            .toList();
        _savingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: BillingText('SKU saved for ${product.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: BillingText(_cleanError(error))),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _skuControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return _SkuError(message: _error!, onRetry: _load);
    }

    final query = _searchQuery.trim().toLowerCase();
    final products = _products
        .where((product) =>
            query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            product.categoryName.toLowerCase().contains(query) ||
            product.sku.toLowerCase().contains(query))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          BillingText(
            'Product SKU manager',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          BillingText(
            '${_products.length} products • store SKUs are unique internal stock codes.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: BillingInputDecoration(
              hintText: 'Find a product or category',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: BillingIconButton(
                tooltip: 'Refresh products',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const AppBanner(
            icon: Icons.info_outline_rounded,
            message:
                'SKUs are set by each store, not assigned globally. Use a clear '
                'category-product-variant code (for example, RPG-PUL-MASOOR-1KG). '
                'A globally standardized product code is a GTIN/barcode, not an SKU.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _SkuNotice(message: _error!),
          ],
          const SizedBox(height: 14),
          if (_products.isEmpty)
            const _SkuEmpty()
          else if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child:
                  Center(child: BillingText('No products match your search.')),
            )
          else
            ...products.map(
              (product) => _SkuProductTile(
                product: product,
                controller: _skuControllers[product.id]!,
                isSaving: _savingId == product.id,
                isDisabled: _savingId != null,
                onSave: () => _saveSku(product),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkuProductTile extends StatelessWidget {
  final AdminProduct product;
  final TextEditingController controller;
  final bool isSaving;
  final bool isDisabled;
  final VoidCallback onSave;

  const _SkuProductTile({
    required this.product,
    required this.controller,
    required this.isSaving,
    required this.isDisabled,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppRowCard(
              title: product.name,
              subtitle: product.categoryName,
              leading:
                  ProductThumbnail(imageUrl: product.imageUrl ?? '', size: 56),
              tint: AppColors.thumbnailBlue,
              trailing: AppStatusPill(
                product.isActive ? 'Active' : 'Inactive',
                variant: product.isActive
                    ? AppStatusVariant.success
                    : AppStatusVariant.neutral,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  enabled: !isDisabled,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.none,
                  decoration: const BillingInputDecoration(
                    labelText: 'SKU',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: isDisabled ? null : onSave,
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const BillingText('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkuNotice extends StatelessWidget {
  final String message;

  const _SkuNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: AppBanner(
        message: message,
        icon: Icons.error_outline_rounded,
        variant: AppStatusVariant.error,
      ),
    );
  }
}

class _SkuEmpty extends StatelessWidget {
  const _SkuEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          const BillingText(
            'No products to update',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          BillingText(
            'Add products in the Products section to manage their SKUs.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SkuError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SkuError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'SKUs unavailable',
        message: message,
        retryLabel: 'Try again',
        onRetry: onRetry,
      );
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
