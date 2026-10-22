import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
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
      if (!mounted) return;
      setState(() {
        _rewards = result.rewards;
        _claims = result.claims;
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

  Future<void> _save() async {
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
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reward milestones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : () => _editReward(),
                icon: const Icon(Icons.add),
                label: const Text('Add day'),
              ),
              const SizedBox(width: 6),
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
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppConstants.primaryLight,
                        child: Text('${reward.day}'),
                      ),
                      title: Text('Day ${reward.day} · ${reward.title}'),
                      subtitle: Text(
                        reward.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                                          .where(
                                              (item) => item.day != reward.day)
                                          .toList(growable: false),
                                    ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 22, 18, 8),
                  child: Text(
                    'Customer reward claims',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_claims.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: Text('No rewards have been claimed yet.'),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _claims.length,
                  itemBuilder: (context, index) {
                    final claim = _claims[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppConstants.primary,
                      ),
                      title: Text(
                        '${claim.customerName} · ${claim.profileId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Day ${claim.day} · ${claim.title} · ${claim.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        MaterialLocalizations.of(context).formatShortDate(
                          DateTime.parse(claim.claimedAt).toLocal(),
                        ),
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
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
  const _StreakRewardDialog({this.existing, required this.usedDays});

  final AdminStreakReward? existing;
  final Set<int> usedDays;

  @override
  State<_StreakRewardDialog> createState() => _StreakRewardDialogState();
}

class _StreakRewardDialogState extends State<_StreakRewardDialog> {
  late final TextEditingController _dayController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dayController =
        TextEditingController(text: widget.existing?.day.toString() ?? '');
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _dayController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
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
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() => _error = 'Add both a reward name and details.');
      return;
    }
    Navigator.pop(
      context,
      AdminStreakReward(
        day: day,
        title: title,
        description: description,
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
            TextField(
              controller: _titleController,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Reward name'),
            ),
            TextField(
              controller: _descriptionController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Reward details'),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
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
