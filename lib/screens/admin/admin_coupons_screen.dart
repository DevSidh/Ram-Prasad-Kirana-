import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
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
      builder: (_) => _CouponFormDialog(api: _adminApi),
    );
    if (coupon == null || !mounted) return;
    setState(() => _coupons = [coupon, ..._coupons]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${coupon.code} is ready for customers.')),
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

  String _discountLabel(AdminCoupon coupon) => coupon.discountType ==
          'PERCENTAGE'
      ? '${coupon.discountPercent?.toStringAsFixed(0) ?? '0'}% off'
      : '${AppConstants.currencySymbol}${coupon.discountAmount?.toStringAsFixed(0) ?? '0'} off';

  Widget _buildCouponCard(AdminCoupon coupon) {
    final statusColor =
        coupon.isActive ? Colors.green.shade700 : AppConstants.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppConstants.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_offer_outlined,
                  color: AppConstants.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.code,
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_discountLabel(coupon)} · Min. ${AppConstants.currencySymbol}${coupon.minOrderAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    coupon.usageLimit == null
                        ? '${coupon.usedCount} uses · ${coupon.isActive ? 'Active' : 'Paused'}'
                        : '${coupon.usedCount}/${coupon.usageLimit} uses · ${coupon.isActive ? 'Active' : 'Paused'}',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (coupon.expiresAt != null)
                    Text(
                      'Expires ${MaterialLocalizations.of(context).formatMediumDate(coupon.expiresAt!.toLocal())}',
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: coupon.isActive,
              onChanged: (value) => _setActive(coupon, value),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promotions',
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active percentage codes with a maximum discount and fixed-amount codes can show the festival popup after sign-in.',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
              final addButton = FilledButton.icon(
                onPressed: _createCoupon,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add code'),
              );
              if (constraints.maxWidth < 390) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: addButton,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  addButton,
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          if (_coupons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined,
                      color: AppConstants.textMuted, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'No promotions yet',
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a discount code for your customers.',
                    style: TextStyle(color: AppConstants.textMuted),
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

class _CouponFormDialog extends StatefulWidget {
  final AdminApiService api;

  const _CouponFormDialog({required this.api});

  @override
  State<_CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<_CouponFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _discount = TextEditingController();
  final _minimum = TextEditingController(text: '0');
  final _maximum = TextEditingController();
  final _usageLimit = TextEditingController();
  String _discountType = 'PERCENTAGE';
  DateTime? _expiresAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _discount.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _usageLimit.dispose();
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
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 10),
    );
    if (selected != null && mounted) setState(() => _expiresAt = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final discount = double.parse(_discount.text.trim());
    try {
      final coupon = await widget.api.createCoupon({
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
        'expiresAt': _expiresAt
            ?.add(const Duration(hours: 23, minutes: 59, seconds: 59))
            .toUtc()
            .toIso8601String(),
      });
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
      title: const Text('Create promotion'),
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
                          ? 'No expiry date'
                          : 'Expires ${MaterialLocalizations.of(context).formatMediumDate(_expiresAt!)}',
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
                        style: const TextStyle(color: Colors.red),
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
                  : const Text('Create code'),
            ),
          ],
        ),
      ],
    );
  }
}
