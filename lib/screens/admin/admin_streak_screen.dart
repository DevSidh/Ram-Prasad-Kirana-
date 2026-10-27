import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import 'admin_coupons_screen.dart';
import '../../widgets/store_animation.dart';

class AdminStreakScreen extends StatefulWidget {
  const AdminStreakScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminStreakScreen> createState() => _AdminStreakScreenState();
}

class _AdminStreakScreenState extends State<AdminStreakScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminStreakReward> _rewards = const [];
  List<AdminStreakClaim> _claims = const [];
  List<AdminCoupon> _coupons = const [];
  bool _loading = true;
  bool _saving = false;
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
      final result = await _adminApi.getStreakRewards();
      final coupons = await _adminApi.getCoupons();
      if (!mounted) return;
      setState(() {
        _rewards = result.rewards;
        _claims = result.claims;
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

  Future<void> _editReward([AdminStreakReward? existing]) async {
    final result = await showDialog<AdminStreakReward>(
      context: context,
      builder: (_) => _StreakRewardDialog(
        existing: existing,
        coupons: _coupons
            .where((coupon) =>
                coupon.isActive &&
                coupon.assignedUserId == null &&
                (coupon.expiresAt == null ||
                    coupon.expiresAt!.isAfter(DateTime.now())))
            .toList(growable: false),
        usedDays: _rewards.map((reward) => reward.day).toSet(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _rewards = [
        ..._rewards.where((reward) => reward.day != existing?.day),
        result,
      ]..sort((a, b) => a.day.compareTo(b.day));
    });
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
          content: Text('${coupon.code} is ready to use for a milestone.')),
    );
  }

  Future<void> _save() async {
    if (_rewards.any((reward) => reward.couponId == null)) {
      setState(() {
        _error = 'Select an active coupon for each streak milestone.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _adminApi.saveStreakRewards(_rewards);
      if (!mounted) return;
      setState(() {
        _rewards = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buying streak rewards saved.')),
      );
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
    if (_loading && _rewards.isEmpty && _claims.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rewards.isEmpty && _claims.isEmpty) {
      return StorePageError(
        title: 'Buying streak unavailable',
        message: _error!,
        retryLabel: 'Try again',
        onRetry: _load,
      );
    }
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 30, 0),
            child: AppBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              variant: AppStatusVariant.error,
              trailing: TextButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 30, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const AppSectionLabel('Reward milestones'),
              TextButton.icon(
                onPressed: _saving ? null : () => _editReward(),
                icon: const Icon(Icons.add),
                label: const Text('Add day'),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _createCoupon,
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Add coupon'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('admin-streak-scroll'),
            slivers: [
              if (_rewards.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 30, 8),
                    child: Text(
                      'No milestones yet. Add a day and describe what the customer can claim.',
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _rewards.length,
                  itemBuilder: (context, index) {
                    final reward = _rewards[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 30, 10),
                      child: AppRowCard(
                        title: 'Day ${reward.day} · ${reward.title}',
                        subtitle: reward.couponCode == null
                            ? 'No coupon selected. Edit this milestone to choose a coupon gift.'
                            : 'Gift coupon ${reward.couponCode}',
                        leading: Text(
                          '${reward.day}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        tint: AppColors.thumbnailAmber,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit day ${reward.day}',
                              onPressed:
                                  _saving ? null : () => _editReward(reward),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Remove day ${reward.day}',
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                        () => _rewards = _rewards
                                            .where((item) =>
                                                item.day != reward.day)
                                            .toList(growable: false),
                                      ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 22, 30, 8),
                  child: AppSectionLabel(
                    'Customer reward claims',
                  ),
                ),
              ),
              if (_claims.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 30, 24),
                    child: Text('No rewards have been claimed yet.'),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _claims.length,
                  itemBuilder: (context, index) {
                    final claim = _claims[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 30, 10),
                      child: AppRowCard(
                        title: '${claim.customerName} · ${claim.profileId}',
                        subtitle:
                            'Day ${claim.day} · ${claim.title} · ${claim.description}',
                        leading: const Icon(Icons.card_giftcard_rounded),
                        tint: AppColors.thumbnailGreen,
                        trailing: Text(
                          MaterialLocalizations.of(context).formatShortDate(
                            DateTime.parse(claim.claimedAt).toLocal(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakRewardDialog extends StatefulWidget {
  const _StreakRewardDialog({
    this.existing,
    required this.coupons,
    required this.usedDays,
  });

  final AdminStreakReward? existing;
  final List<AdminCoupon> coupons;
  final Set<int> usedDays;

  @override
  State<_StreakRewardDialog> createState() => _StreakRewardDialogState();
}

class _StreakRewardDialogState extends State<_StreakRewardDialog> {
  late final TextEditingController _dayController;
  String? _couponId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dayController =
        TextEditingController(text: widget.existing?.day.toString() ?? '');
    _couponId = widget.existing?.couponId;
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  void _save() {
    final day = int.tryParse(_dayController.text.trim());
    if (day == null || day < 1 || day > 365) {
      setState(() => _error = 'Enter a streak day between 1 and 365.');
      return;
    }
    if (widget.usedDays.contains(day) && day != widget.existing?.day) {
      setState(() => _error = 'A reward already exists for day $day.');
      return;
    }
    AdminCoupon? coupon;
    for (final item in widget.coupons) {
      if (item.id == _couponId) {
        coupon = item;
        break;
      }
    }
    if (coupon == null) {
      setState(() => _error = 'Choose an active coupon to gift.');
      return;
    }
    Navigator.pop(
      context,
      AdminStreakReward(
        day: day,
        title: 'Coupon gift',
        description: 'Claim this milestone to receive coupon ${coupon.code}.',
        couponId: coupon.id,
        couponCode: coupon.code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Add streak reward' : 'Edit reward'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Streak day'),
            ),
            DropdownButtonFormField<String>(
              initialValue: widget.coupons.any(
                (coupon) => coupon.id == _couponId,
              )
                  ? _couponId
                  : null,
              decoration: const InputDecoration(labelText: 'Coupon gift'),
              items: widget.coupons
                  .map(
                    (coupon) => DropdownMenuItem(
                      value: coupon.id,
                      child: Text(coupon.code),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _couponId = value),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.errorText),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save reward')),
      ],
    );
  }
}
