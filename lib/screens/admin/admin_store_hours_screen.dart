import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store_availability.dart';
import '../../providers/store_availability_provider.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';

class AdminStoreHoursScreen extends StatefulWidget {
  const AdminStoreHoursScreen({super.key});

  @override
  State<AdminStoreHoursScreen> createState() => _AdminStoreHoursScreenState();
}

class _AdminStoreHoursScreenState extends State<AdminStoreHoursScreen> {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final AdminApiService _api;
  bool _loading = true;
  bool _saving = false;
  bool _isOrderingEnabled = true;
  List<StoreHoursDay> _weeklyHours = [];
  String? _error;
  StoreAvailability? _availability;

  @override
  void initState() {
    super.initState();
    _api = AdminApiService(context.read<ApiService>());
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final availability = await _api.getStoreSettings();
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _isOrderingEnabled = availability.isOrderingEnabled;
        _weeklyHours = availability.weeklyHours;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateDay(int day, StoreHoursDay Function(StoreHoursDay) update) {
    final index = _weeklyHours.indexWhere((hours) => hours.day == day);
    if (index < 0) return;
    setState(() => _weeklyHours[index] = update(_weeklyHours[index]));
  }

  Future<void> _selectTime(int day, bool opening) async {
    final hours = _weeklyHours.firstWhere((entry) => entry.day == day);
    final value = opening ? hours.openTime : hours.closeTime;
    final initialTime = TimeOfDay(
      hour: int.parse(value.substring(0, 2)),
      minute: int.parse(value.substring(3, 5)),
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: opening ? 'Select opening time' : 'Select closing time',
    );
    if (selected == null || !mounted) return;
    final time =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    _updateDay(
      day,
      (entry) => entry.copyWith(
        openTime: opening ? time : null,
        closeTime: opening ? null : time,
      ),
    );
  }

  Future<void> _save({
    bool? rollbackOrderingEnabled,
    String successMessage = 'Store hours saved.',
  }) async {
    final invalidDay = _weeklyHours.where((hours) =>
        hours.isOpen && hours.openTime.compareTo(hours.closeTime) >= 0);
    if (invalidDay.isNotEmpty) {
      setState(() {
        _error =
            'Set the closing time later than the opening time for ${_weekdays[invalidDay.first.day - 1]}.';
        if (rollbackOrderingEnabled != null) {
          _isOrderingEnabled = rollbackOrderingEnabled;
        }
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final availability = await _api.updateStoreSettings(
        isOrderingEnabled: _isOrderingEnabled,
        weeklyHours: _weeklyHours,
      );
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _isOrderingEnabled = availability.isOrderingEnabled;
        _weeklyHours = availability.weeklyHours;
      });
      context.read<StoreAvailabilityProvider>().setAvailability(availability);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        if (rollbackOrderingEnabled != null) {
          _isOrderingEnabled = rollbackOrderingEnabled;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleOrdering(bool enabled) async {
    final previousValue = _isOrderingEnabled;
    setState(() => _isOrderingEnabled = enabled);
    await _save(
      rollbackOrderingEnabled: previousValue,
      successMessage: enabled ? 'Online ordering resumed.' : 'Orders paused.',
    );
  }

  Widget _buildAvailabilityCard() {
    final availability = _availability;
    final isAcceptingOrders = availability?.isAcceptingOrders ?? false;
    return AppBanner(
      icon:
          isAcceptingOrders ? Icons.storefront_rounded : Icons.schedule_rounded,
      message:
          '${isAcceptingOrders ? 'Accepting orders' : 'Not accepting orders'}'
          ' · ${availability?.statusMessage ?? 'Save your weekly hours to show customers when you are open.'}',
      variant: isAcceptingOrders
          ? AppStatusVariant.success
          : AppStatusVariant.warning,
    );
  }

  Widget _buildDayRow(StoreHoursDay hours) {
    final dayName = _weekdays[hours.day - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.row),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  dayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(hours.isOpen ? 'Open' : 'Closed'),
                value: hours.isOpen,
                onChanged: _saving
                    ? null
                    : (isOpen) => _updateDay(
                          hours.day,
                          (entry) => entry.copyWith(isOpen: isOpen),
                        ),
              ),
              if (hours.isOpen)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _saving ? null : () => _selectTime(hours.day, true),
                        icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                        label: Text('Opens ${hours.openTime}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _selectTime(hours.day, false),
                        icon: const Icon(Icons.nights_stay_outlined, size: 18),
                        label: Text('Closes ${hours.closeTime}'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_weeklyHours.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Store hours could not be loaded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.errorText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  unawaited(_load());
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
      children: [
        _buildAvailabilityCard(),
        const SizedBox(height: 18),
        Card(
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              'Accept online orders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              _isOrderingEnabled
                  ? 'Orders follow the weekly hours below. Switching off pauses orders immediately.'
                  : 'Ordering is paused for every customer.',
            ),
            value: _isOrderingEnabled,
            onChanged: _saving ? null : _toggleOrdering,
          ),
        ),
        const SizedBox(height: 20),
        const AppSectionLabel('Weekly opening hours'),
        const SizedBox(height: 4),
        Text(
          'Times use Nepal Standard Time (${_availability?.timeZone ?? 'Asia/Kathmandu'}).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 640
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hours in _weeklyHours)
                  SizedBox(width: cardWidth, child: _buildDayRow(hours)),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          AppBanner(
            message: _error!,
            icon: Icons.error_outline_rounded,
            variant: AppStatusVariant.error,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'Saving...' : 'Save store hours'),
        ),
      ],
    );
  }
}
