import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer_menu_features.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class CustomerMenuSettingsScreen extends StatefulWidget {
  const CustomerMenuSettingsScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<CustomerMenuSettingsScreen> createState() =>
      _CustomerMenuSettingsScreenState();
}

class _CustomerMenuSettingsScreenState
    extends State<CustomerMenuSettingsScreen> {
  static const _labels = <String, String>{
    'orders': 'Orders',
    'addresses': 'Delivery addresses',
    'savedItems': 'Saved items',
    'buyingStreak': 'Buying-day streak',
    'appearance': 'Theme switch',
    'language': 'Language selector',
    'payments': 'Payment methods',
    'notifications': 'Notifications',
    'notificationPreferences': 'Notification preferences',
    'coupons': 'Coupons',
    'help': 'Help and store information',
    'legal': 'Legal pages',
    'deleteAccount': 'Delete account',
  };

  late final AdminApiService _adminApi = AdminApiService(widget.api);
  Map<String, bool> _features = CustomerMenuFeatures.defaults.toJson();
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
      final result = await _adminApi.getCustomerMenuFeatures();
      if (!mounted) return;
      setState(() {
        _features = CustomerMenuFeatures.fromJson(result).toJson();
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _adminApi.saveCustomerMenuFeatures(_features);
      if (!mounted) return;
      setState(() {
        _features = CustomerMenuFeatures.fromJson(saved).toJson();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer menu controls saved.')),
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer menu controls')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer menu controls'),
        actions: [
          TextButton(
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Choose which options are available in every customer profile menu. Turning an item off hides its entry; it does not delete the customer’s data.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final key in CustomerMenuFeatures.keys)
                  SwitchListTile(
                    title: Text(_labels[key] ?? key),
                    value: _features[key] ?? true,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _features[key] = value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
