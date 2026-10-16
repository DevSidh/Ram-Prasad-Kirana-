import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/store_animation.dart';

class AdminCategoriesScreen extends StatefulWidget {
  final ApiService api;

  const AdminCategoriesScreen({super.key, required this.api});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminCategory> _categories = [];
  String? _error;
  bool _loading = true;

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
      final categories = await _adminApi.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  Future<void> _editCategory([AdminCategory? category]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(api: _adminApi, category: category),
    );
    if (saved == true) _load();
  }

  Future<void> _deactivate(AdminCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate category?'),
        content: Text(
          '“${category.name}” will no longer be available to customers. Existing products will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _adminApi.updateCategory(category.id, {'isActive': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category.name} deactivated')),
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      _showError(_cleanError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _categories.isEmpty) {
      return _LoadError(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Organize the shelves', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Categories are shared with your store catalog.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editCategory(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          if (_categories.isEmpty)
            _EmptyCategories(onAdd: () => _editCategory())
          else
            ..._categories.map(
              (category) => _CategoryCard(
                category: category,
                onEdit: () => _editCategory(category),
                onDeactivate: category.isActive ? () => _deactivate(category) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final AdminApiService api;
  final AdminCategory? category;

  const _CategoryFormDialog({required this.api, this.category});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  bool _slugEdited = false;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _slugController = TextEditingController(text: widget.category?.slug ?? '');
    _descriptionController = TextEditingController(text: widget.category?.description ?? '');
    _imageUrlController =
        TextEditingController(text: widget.category?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
      setState(() {
        _uploadingImage = true;
        _error = null;
      });
      final imageUrl = await widget.api.uploadImage(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _imageUrlController.text = imageUrl;
        _uploadingImage = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'slug': _slugController.text.trim().isEmpty
          ? _slugify(_nameController.text)
          : _slugify(_slugController.text),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'imageUrl': _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
    };
    try {
      if (widget.category == null) {
        await widget.api.createCategory(data);
      } else {
        await widget.api.updateCategory(widget.category!.id, data);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 420,
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
                  decoration: const InputDecoration(labelText: 'Category name'),
                  onChanged: (value) {
                    if (!_slugEdited) _slugController.text = _slugify(value);
                  },
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a category name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'URL slug'),
                  onChanged: (_) => _slugEdited = true,
                  validator: (value) => value == null || _slugify(value).isEmpty
                      ? 'Enter a valid slug'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ProductThumbnail(
                      imageUrl: _imageUrlController.text,
                      size: 56,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.category_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingImage ? null : _pickImage,
                        icon: _uploadingImage
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_outlined),
                        label: Text(
                          _uploadingImage ? 'Uploading image…' : 'Upload image',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    helperText: 'Upload an image or paste a URL.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _uploadingImage
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _uploadingImage ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save category'),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AdminCategory category;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppConstants.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: ProductThumbnail(
              imageUrl: category.imageUrl ?? '',
              size: 48,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
              fallbackIcon: Icons.category_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(category.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 7),
                    _StatusTag(active: category.isActive),
                  ],
                ),
                const SizedBox(height: 3),
                Text(category.slug, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                if (category.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(category.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Category actions',
            onSelected: (action) {
              if (action == 'edit') onEdit();
              if (action == 'deactivate') onDeactivate?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (onDeactivate != null)
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final bool active;

  const _StatusTag({required this.active});

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
            color: active ? const Color(0xFF047857) : AppConstants.textMuted,
          ),
        ),
      );
}

class _EmptyCategories extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCategories({required this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: AppConstants.surfaceLight, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppConstants.borderLight)),
        child: Column(
          children: [
            Icon(Icons.category_outlined, size: 34, color: AppConstants.textMuted),
            const SizedBox(height: 10),
            const Text('No categories yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('Create your first category to group store products.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppConstants.textMuted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create category'),
            ),
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'Categories unavailable',
        message: message,
        retryLabel: 'Try again',
        onRetry: onRetry,
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
        child: Text(message, style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12)),
      );
}

String _slugify(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');
