import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/media.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminShowcaseScreen extends StatefulWidget {
  final ApiService api;
  final void Function(String productId, bool isFeatured)? onFeaturedChanged;
  final void Function(String productId, String imageUrl)?
      onProductImageChanged;

  const AdminShowcaseScreen({
    super.key,
    required this.api,
    this.onFeaturedChanged,
    this.onProductImageChanged,
  });

  @override
  State<AdminShowcaseScreen> createState() => _AdminShowcaseScreenState();
}

class _AdminShowcaseScreenState extends State<AdminShowcaseScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminProduct> _products = [];
  bool _loading = true;
  String? _error;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _adminApi.getAllProducts();
      if (!mounted) return;
      products.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() {
        _products = products;
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

  Future<void> _setFeatured(AdminProduct product, bool isFeatured) async {
    setState(() => _savingId = product.id);
    try {
      await _adminApi.updateProductFeatured(product.id, isFeatured);
      if (!mounted) return;
      widget.onFeaturedChanged?.call(product.id, isFeatured);
      setState(() {
        _products = _products
            .map(
              (item) => item.id == product.id
                  ? item.copyWith(isFeatured: isFeatured)
                  : item,
            )
            .toList()
          ..sort((a, b) {
            if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        _savingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFeatured
                ? '${product.name} added to the home carousel'
                : '${product.name} removed from the home carousel',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    }
  }

  Future<void> _pickCarouselImage(AdminProduct product) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.first;
      final size = await file.length();
      if (size == null) {
        throw Exception('Unable to read that image. Choose another file.');
      }
      if (size > 5 * 1024 * 1024) {
        throw Exception('Choose an image smaller than 5 MB.');
      }
      final extension = file.extension?.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw Exception('Choose a JPEG, PNG, or WebP image.');
      }
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _savingId = product.id);
      final imageUrl = await _adminApi.uploadProductImage(bytes, file.name);
      await _adminApi.updateProductImage(product.id, imageUrl);
      if (!mounted) return;
      widget.onProductImageChanged?.call(product.id, imageUrl);
      setState(() {
        _products = _products
            .map(
              (item) => item.id == product.id
                  ? item.copyWith(imageUrl: imageUrl)
                  : item,
            )
            .toList();
        _savingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} carousel image updated')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return _ShowcaseError(message: _error!, onRetry: _load);
    }

    final featuredCount = _products
        .where((product) => product.isFeatured && product.isActive)
        .length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text(
            'Homepage carousel',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose the products that rotate in the customer storefront. '
            'Images fill a fixed, responsive slide area, so source-image proportions do not resize the card. '
            'Changing a carousel image also updates that product image across the store.',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppConstants.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_carousel_rounded,
                    color: AppConstants.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$featuredCount ${featuredCount == 1 ? 'product' : 'products'} '
                    'currently featured • active products rotate automatically',
                    style: const TextStyle(
                      color: AppConstants.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh products',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ShowcaseNotice(message: _error!),
          ],
          const SizedBox(height: 16),
          if (_products.isEmpty)
            const _ShowcaseEmpty()
          else
            ..._products.map(
              (product) => _ShowcaseProductTile(
                product: product,
                isSaving: _savingId == product.id,
                onImageChanged: product.isFeatured && _savingId == null
                    ? () => _pickCarouselImage(product)
                    : null,
                onChanged: (product.isActive || product.isFeatured) &&
                        _savingId == null
                    ? (value) => _setFeatured(product, value)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowcaseProductTile extends StatelessWidget {
  final AdminProduct product;
  final bool isSaving;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onImageChanged;

  const _ShowcaseProductTile({
    required this.product,
    required this.isSaving,
    required this.onChanged,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 76,
              height: 64,
              child: product.imageUrl == null || product.imageUrl!.isEmpty
                  ? const ColoredBox(
                      color: AppConstants.primaryLight,
                      child: Icon(Icons.shopping_basket_outlined,
                          color: AppConstants.primary),
                    )
                  : Image.network(
                      optimizedProductImageUrl(product.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppConstants.primaryLight,
                        child: Icon(Icons.broken_image_outlined,
                            color: AppConstants.primary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product.categoryName} • Rs. ${product.price.toStringAsFixed(0)}'
                  '${product.isActive ? '' : ' • Inactive'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppConstants.textMuted, fontSize: 11),
                ),
                if (onImageChanged != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: isSaving ? null : onImageChanged,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 16),
                    label: Text(
                      product.imageUrl == null || product.imageUrl!.isEmpty
                          ? 'Add carousel image'
                          : 'Change carousel image',
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isSaving)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Semantics(
              label: 'Feature ${product.name} in the homepage carousel',
              child: Switch(
                value: product.isFeatured,
                onChanged: onChanged,
                activeThumbColor: AppConstants.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowcaseNotice extends StatelessWidget {
  final String message;

  const _ShowcaseNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF7A4A00))),
    );
  }
}

class _ShowcaseEmpty extends StatelessWidget {
  const _ShowcaseEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 42, color: AppConstants.textMuted),
          SizedBox(height: 12),
          Text(
            'No products to feature yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Add products in the Products section first.',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ShowcaseError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppConstants.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
