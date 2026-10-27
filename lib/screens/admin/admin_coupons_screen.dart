import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/store_animation.dart';

class AdminCouponsScreen extends StatefulWidget {
  final ApiService api;

  const AdminCouponsScreen({super.key, required this.api});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminCoupon> _coupons = [];
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
      final coupons = await _adminApi.getCoupons();
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
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

  Future<void> _createCoupon() async {
    final coupon = await showDialog<AdminCoupon>(
      context: context,
      builder: (_) => AdminCouponFormDialog(api: _adminApi),
    );
    if (coupon == null || !mounted) return;
    setState(() => _coupons = [coupon, ..._coupons]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${coupon.code} is saved as a draft. Add it to an announcement to share it.',
        ),
      ),
    );
  }

  Future<void> _issueProductCoupon() async {
    final coupon = await showDialog<AdminCoupon>(
      context: context,
      builder: (_) => _ProductCouponDialog(api: _adminApi),
    );
    if (coupon == null || !mounted) return;
    setState(() => _coupons = [coupon, ..._coupons]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${coupon.code} sent to the selected customer.')),
    );
  }

  Future<void> _editCoupon(AdminCoupon current) async {
    final updated = await showDialog<AdminCoupon>(
      context: context,
      builder: (_) => AdminCouponFormDialog(api: _adminApi, coupon: current),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _coupons = _coupons
          .map((coupon) => coupon.id == updated.id ? updated : coupon)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.code} updated.')),
    );
  }

  Future<void> _setActive(AdminCoupon coupon, bool isActive) async {
    try {
      final updated = await _adminApi.setCouponActive(coupon.id, isActive);
      if (!mounted) return;
      setState(() {
        _coupons = _coupons
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive ? '${coupon.code} activated.' : '${coupon.code} paused.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _setBannerCoupon(AdminCoupon? selected) async {
    final current =
        _coupons.where((coupon) => coupon.isBannerFeatured).toList();
    final target = selected;
    try {
      for (final coupon in current) {
        if (target == null || coupon.id != target.id) {
          await _adminApi.setCouponBanner(coupon.id, false);
        }
      }
      if (target != null && !target.isBannerFeatured) {
        await _adminApi.setCouponBanner(target.id, true);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(target == null
              ? 'Promotion banner coupon cleared.'
              : '${target.code} selected for the promotion banner.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update banner coupon: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _removeCoupon(AdminCoupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${coupon.code}?'),
        content: const Text(
          'This coupon will no longer be available at checkout. Existing order history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep coupon'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove coupon'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final previousCoupons = _coupons;
    setState(() {
      _coupons = _coupons.where((item) => item.id != coupon.id).toList();
    });
    try {
      await _adminApi.removeCoupon(coupon.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${coupon.code} was removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _coupons = previousCoupons);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove ${coupon.code}: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  String _discountLabel(AdminCoupon coupon) => coupon.discountType ==
          'PERCENTAGE'
      ? '${coupon.discountPercent?.toStringAsFixed(0) ?? '0'}% off'
      : '${AppConstants.currencySymbol}${coupon.discountAmount?.toStringAsFixed(0) ?? '0'} off';

  Widget _buildCouponCard(AdminCoupon coupon) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          coupon.code,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (coupon.productId != null || coupon.assignedUserId != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Product-specific · assigned to one customer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warningText,
                  ),
            ),
          ),
        const SizedBox(height: 3),
        Text(
          '${_discountLabel(coupon)} · Min. ${AppConstants.currencySymbol}${coupon.minOrderAmount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 3),
        Text(
          coupon.usageLimit == null
              ? '${coupon.usedCount} uses'
              : '${coupon.usedCount}/${coupon.usageLimit} uses',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            AppStatusPill(
              coupon.isActive ? 'Active' : 'Inactive',
              variant: coupon.isActive
                  ? AppStatusVariant.success
                  : AppStatusVariant.neutral,
            ),
            AppStatusPill(
              coupon.isAnnounced ? 'Announced' : 'Draft',
              variant: AppStatusVariant.neutral,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          coupon.perUserLimit == null
              ? 'Unlimited uses per customer'
              : '${coupon.perUserLimit} use${coupon.perUserLimit == 1 ? '' : 's'} per customer',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (coupon.expiresAt != null)
          Text(
            'Expires ${MaterialLocalizations.of(context).formatMediumDate(coupon.expiresAt!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(coupon.expiresAt!.toLocal()))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
    final actions = Wrap(
      spacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Switch(
          value: coupon.isActive,
          onChanged: (value) => _setActive(coupon, value),
        ),
        IconButton(
          tooltip: 'Edit ${coupon.code}',
          onPressed: () => _editCoupon(coupon),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Remove ${coupon.code}',
          onPressed: () => _removeCoupon(coupon),
          icon: Icon(Icons.delete_outline, color: AppColors.errorText),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final productInfo = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.thumbnailAmber,
                borderRadius: BorderRadius.circular(AppRadii.thumbnail),
              ),
              child: Icon(
                Icons.local_offer_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: details),
            if (!compact) ...[
              const SizedBox(width: 10),
              actions,
            ],
          ],
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productInfo,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actions,
                    ),
                  ],
                )
              : productInfo,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _coupons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _coupons.isEmpty) {
      return StorePageError(
        title: 'Coupons unavailable',
        message: _error!,
        retryLabel: 'Try again',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          if (!_loading && _error == null && _coupons.isNotEmpty)
            AppSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Promotion banner coupon',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          'Choose which promotion code is featured on the store banner.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _coupons
                              .any((coupon) => coupon.isBannerFeatured)
                          ? _coupons
                              .firstWhere((coupon) => coupon.isBannerFeatured)
                              .id
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Banner coupon',
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: const Text('No coupon'),
                        ),
                        for (final coupon in _coupons.where(
                          (coupon) =>
                              coupon.productId == null && coupon.isActive,
                        ))
                          DropdownMenuItem<String?>(
                            value: coupon.id,
                            child: Text(coupon.code),
                          ),
                      ],
                      onChanged: (id) => _setBannerCoupon(id == null
                          ? null
                          : _coupons.firstWhere((coupon) => coupon.id == id)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            final coupon = _coupons.where((item) =>
                                item.code.toUpperCase() == 'DIWALI50');
                            if (coupon.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'DIWALI50 is not in Promotions yet. Add or activate it first.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!coupon.first.isActive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Activate DIWALI50 before featuring it on the banner.',
                                  ),
                                ),
                              );
                              return;
                            }
                            unawaited(_setBannerCoupon(coupon.first));
                          },
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: const Text('Feature DIWALI50'),
                  ),
                ],
              ),
            ),
          if (!_loading && _error == null && _coupons.isNotEmpty)
            const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Text(
                'New store-wide codes stay as drafts until you attach them to an announcement. Product discounts go to one customer.',
                style: Theme.of(context).textTheme.bodySmall,
              );
              final addButton = FilledButton.icon(
                onPressed: _createCoupon,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add code'),
              );
              final productCouponButton = OutlinedButton.icon(
                onPressed: _issueProductCoupon,
                icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                label: const Text('Give product coupon'),
              );
              if (constraints.maxWidth < 390) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        addButton,
                        productCouponButton,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  productCouponButton,
                  const SizedBox(width: 8),
                  addButton,
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.errorText)),
          ],
          const SizedBox(height: 16),
          if (_coupons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined,
                      color: AppColors.muted, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'No promotions yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a discount code for your customers.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            ..._coupons.map(_buildCouponCard),
        ],
      ),
    );
  }
}

class AdminCouponFormDialog extends StatefulWidget {
  final AdminApiService api;
  final AdminCoupon? coupon;

  const AdminCouponFormDialog({super.key, required this.api, this.coupon});

  @override
  State<AdminCouponFormDialog> createState() => _AdminCouponFormDialogState();
}

class _ProductCouponDialog extends StatefulWidget {
  const _ProductCouponDialog({required this.api});

  final AdminApiService api;

  @override
  State<_ProductCouponDialog> createState() => _ProductCouponDialogState();
}

class _ProductCouponDialogState extends State<_ProductCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _discountController = TextEditingController(text: '10');
  Timer? _customerSearchTimer;
  List<AdminCustomer> _customerResults = const [];
  List<AdminProduct> _products = const [];
  AdminCustomer? _selectedCustomer;
  AdminProduct? _selectedProduct;
  String _discountType = 'PERCENTAGE';
  String? _error;
  bool _loadingProducts = true;
  bool _loadingCustomers = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    _customerSearchTimer?.cancel();
    _customerController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final page = await widget.api.getProducts(page: 1, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _products = page.products
            .where((product) => product.isActive && product.availableStock > 0)
            .toList(growable: false);
        _loadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingProducts = false;
      });
    }
  }

  void _searchCustomers(String query) {
    _customerSearchTimer?.cancel();
    setState(() {
      _selectedCustomer = null;
      _customerResults = const [];
      _loadingCustomers = query.trim().isNotEmpty;
      _error = null;
    });
    if (query.trim().isEmpty) return;
    _customerSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final page = await widget.api.getCustomers(
          page: 1,
          pageSize: 8,
          search: query.trim(),
        );
        if (!mounted || _customerController.text.trim() != query.trim()) {
          return;
        }
        setState(() {
          _customerResults = page.customers;
          _loadingCustomers = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _loadingCustomers = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final customer = _selectedCustomer;
    final product = _selectedProduct;
    if (customer == null || product == null) {
      setState(() => _error = 'Choose a customer and an available product.');
      return;
    }
    final discountValue = double.parse(_discountController.text.trim());
    if (_discountType == 'FIXED' && discountValue > product.price) {
      setState(() => _error = 'The discount cannot exceed the product price.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final coupon = await widget.api.issueProductCoupon(
        customerId: customer.id,
        productId: product.id,
        discountType: _discountType,
        discountValue: discountValue,
      );
      if (mounted) Navigator.pop(context, coupon);
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
      title: const Text('Give a product coupon'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'The code will only work for the selected customer and product. It can be used once and expires in 30 days.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _customerController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Find customer by profile ID or email',
                    suffixIcon: _loadingCustomers
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                  onChanged: _searchCustomers,
                ),
                if (_customerResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outline),
                      borderRadius: BorderRadius.circular(AppRadii.input),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _customerResults.length,
                      itemBuilder: (context, index) {
                        final customer = _customerResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${customer.profileId} · ${customer.email}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => setState(() {
                            _selectedCustomer = customer;
                            _customerController.text =
                                '${customer.profileId} · ${customer.name}';
                            _customerResults = const [];
                          }),
                        );
                      },
                    ),
                  ),
                if (_selectedCustomer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Selected: ${_selectedCustomer!.profileId}',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminProduct>(
                  initialValue: _selectedProduct,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product,
                          child: Text(
                            '${product.name} · ${AppConstants.currencySymbol}${product.price.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (product) => setState(() => _selectedProduct = product),
                  validator: (_) =>
                      _selectedProduct == null ? 'Choose a product' : null,
                ),
                if (_loadingProducts)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No in-stock products are available.'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  decoration: const InputDecoration(labelText: 'Discount type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'PERCENTAGE',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(
                        value: 'FIXED', child: Text('Fixed amount')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _discountType = value);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountController,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _discountType == 'PERCENTAGE'
                        ? 'Discount percentage'
                        : 'Discount amount',
                    prefixText: _discountType == 'FIXED'
                        ? '${AppConstants.currencySymbol} '
                        : null,
                    suffixText: _discountType == 'PERCENTAGE' ? '%' : null,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        (_discountType == 'PERCENTAGE' && amount > 100)) {
                      return _discountType == 'PERCENTAGE'
                          ? 'Enter a value from 1 to 100'
                          : 'Enter a valid discount amount';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _saving || _loadingProducts || _products.isEmpty ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send coupon'),
        ),
      ],
    );
  }
}

class _AdminCouponFormDialogState extends State<AdminCouponFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _discount = TextEditingController();
  final _minimum = TextEditingController(text: '0');
  final _maximum = TextEditingController();
  final _usageLimit = TextEditingController();
  final _perUserLimit = TextEditingController();
  String _discountType = 'PERCENTAGE';
  DateTime? _expiresAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final coupon = widget.coupon;
    if (coupon == null) return;
    _code.text = coupon.code;
    _discountType = coupon.discountType;
    _discount.text = (coupon.discountType == 'PERCENTAGE'
                ? coupon.discountPercent
                : coupon.discountAmount)
            ?.toString() ??
        '';
    _minimum.text = coupon.minOrderAmount.toString();
    _maximum.text = coupon.maxDiscount?.toString() ?? '';
    _usageLimit.text = coupon.usageLimit?.toString() ?? '';
    _perUserLimit.text = coupon.perUserLimit?.toString() ?? '';
    _expiresAt = coupon.expiresAt?.toLocal();
  }

  @override
  void dispose() {
    _code.dispose();
    _discount.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    super.dispose();
  }

  String? _positiveAmount(String? value, {bool allowZero = false}) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null ||
        !amount.isFinite ||
        (allowZero ? amount < 0 : amount <= 0)) {
      return allowZero
          ? 'Enter zero or a positive amount.'
          : 'Enter an amount above zero.';
    }
    return null;
  }

  Future<void> _chooseExpiry() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? today,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 10),
    );
    if (selected == null || !mounted) return;
    final current = _expiresAt ??
        DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
        );
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selectedTime == null || !mounted) return;
    setState(() {
      _expiresAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final discount = double.parse(_discount.text.trim());
    try {
      final details = {
        'code': _code.text.trim().toUpperCase(),
        'discountType': _discountType,
        'discountPercent': _discountType == 'PERCENTAGE' ? discount : null,
        'discountAmount': _discountType == 'FIXED' ? discount : null,
        'minOrderAmount': double.parse(_minimum.text.trim()),
        'maxDiscount':
            _discountType == 'PERCENTAGE' && _maximum.text.trim().isNotEmpty
                ? double.parse(_maximum.text.trim())
                : null,
        'usageLimit': _usageLimit.text.trim().isEmpty
            ? null
            : int.parse(_usageLimit.text.trim()),
        'perUserLimit': _perUserLimit.text.trim().isEmpty
            ? null
            : int.parse(_perUserLimit.text.trim()),
        'expiresAt': _expiresAt?.toUtc().toIso8601String(),
      };
      final coupon = widget.coupon == null
          ? await widget.api.createCoupon(details)
          : await widget.api.updateCoupon(widget.coupon!.id, details);
      if (mounted) Navigator.pop(context, coupon);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPercentage = _discountType == 'PERCENTAGE';
    return AlertDialog(
      title:
          Text(widget.coupon == null ? 'Create promotion' : 'Edit promotion'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Coupon code',
                    hintText: 'e.g. SAVE10',
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.length < 3 || code.length > 40) {
                      return 'Use 3–40 letters, numbers, _ or -.';
                    }
                    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$')
                        .hasMatch(code)) {
                      return 'Use only letters, numbers, _ or -.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Coupon names and start dates are not stored by this system yet. Expiration date and time are supported.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Discount type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'PERCENTAGE',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(
                        value: 'FIXED', child: Text('Fixed amount')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _discountType = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        isPercentage ? 'Discount percent' : 'Discount amount',
                    suffixText:
                        isPercentage ? '%' : AppConstants.currencySymbol,
                  ),
                  validator: (value) {
                    final error = _positiveAmount(value);
                    if (error != null) return error;
                    if (isPercentage && double.parse(value!.trim()) > 100) {
                      return 'Percentage cannot exceed 100.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minimum,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum eligible subtotal (retail items)',
                  ),
                  validator: (value) => _positiveAmount(value, allowZero: true),
                ),
                if (isPercentage) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maximum,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Maximum discount (optional)',
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? null
                        : _positiveAmount(value),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usageLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total uses (optional)',
                    helperText: 'Leave empty for unlimited redemptions.',
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return null;
                    final limit = int.tryParse(value!.trim());
                    if (limit == null || limit < 1) {
                      return 'Enter a whole number above zero.';
                    }
                    if (limit < (widget.coupon?.usedCount ?? 0)) {
                      return 'Cannot be lower than ${widget.coupon!.usedCount} uses already recorded.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _perUserLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uses per customer (optional)',
                    helperText:
                        'Limit redemptions per signed-in customer account.',
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return null;
                    final limit = int.tryParse(value!.trim());
                    return limit == null || limit < 1
                        ? 'Enter a whole number above zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseExpiry,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expiresAt == null
                          ? 'No expiry date/time'
                          : 'Expires ${MaterialLocalizations.of(context).formatMediumDate(_expiresAt!)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_expiresAt!))}',
                    ),
                  ),
                ),
                if (_expiresAt != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _expiresAt = null),
                      child: const Text('Remove expiry'),
                    ),
                  ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.errorText),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
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
                  : Text(
                      widget.coupon == null ? 'Create code' : 'Save changes'),
            ),
          ],
        ),
      ],
    );
  }
}
