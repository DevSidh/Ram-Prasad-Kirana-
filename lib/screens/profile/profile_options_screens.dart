import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';

class PaymentPreferenceScreen extends StatefulWidget {
  const PaymentPreferenceScreen({super.key});

  @override
  State<PaymentPreferenceScreen> createState() =>
      _PaymentPreferenceScreenState();
}

class _PaymentPreferenceScreenState extends State<PaymentPreferenceScreen> {
  String _selected = 'COD';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString('preferred_payment_method');
    if (value != null && mounted) setState(() => _selected = value);
  }

  Future<void> _select(String method) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('preferred_payment_method', method);
      if (!mounted) return;
      setState(() => _selected = method);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout preference saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save payment preference: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment preference')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose what to preselect at checkout',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'No card details are stored. You can change the payment option for every order.',
              style: TextStyle(color: AppConstants.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
            _PaymentOption(
              title: 'Cash on delivery',
              detail: 'Pay when your Janakpur delivery arrives.',
              icon: Icons.payments_outlined,
              selected: _selected == 'COD',
              onTap: () => _select('COD'),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              title: 'Khalti wallet',
              detail: 'Use Khalti when available at checkout.',
              icon: Icons.account_balance_wallet_outlined,
              selected: _selected == 'KHALTI',
              onTap: () => _select('KHALTI'),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              title: 'eSewa wallet',
              detail: 'Use eSewa when available at checkout.',
              icon: Icons.wallet_outlined,
              selected: _selected == 'ESEWA',
              onTap: () => _select('ESEWA'),
            ),
          ],
        ),
      );
}

class _PaymentOption extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          minVerticalPadding: 14,
          onTap: onTap,
          leading: Icon(icon, color: AppConstants.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(detail),
          trailing: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? AppConstants.primary : AppConstants.textMuted,
          ),
        ),
      );
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const _keys = {
    'Order updates': 'notifications_order_updates',
    'Delivery updates': 'notifications_delivery_updates',
    'Store offers': 'notifications_store_offers',
  };
  Map<String, bool> _values = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _values = {
        for (final entry in _keys.entries)
          entry.key: preferences.getBool(entry.value) ?? true,
      };
    });
  }

  Future<void> _setValue(String label, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _keys[label]!;
    await preferences.setBool(key, value);
    if (mounted) setState(() => _values[label] = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification preferences')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose the updates you want',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'These choices are saved on this device. Enable push alerts from the Notifications screen and allow them in your device settings.',
              style: TextStyle(color: AppConstants.textMuted, height: 1.45),
            ),
            const SizedBox(height: 18),
            for (final label in _keys.keys)
              Card(
                child: SwitchListTile(
                  value: _values[label] ?? true,
                  onChanged: (value) => _setValue(label, value),
                  title: Text(label),
                  activeThumbColor: AppConstants.primary,
                ),
              ),
          ],
        ),
      );
}

class StoreHelpScreen extends StatelessWidget {
  const StoreHelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Store help')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'How can we help?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 18),
            _HelpBlock(
              title: 'Delivery area',
              detail:
                  'Ram Prasad General Store currently delivers within Janakpur. Add your full ward and street details to your delivery address.',
              icon: Icons.location_on_outlined,
            ),
            _HelpBlock(
              title: 'Update an address',
              detail:
                  'Open Account → Delivery Addresses to add, edit, remove, or choose your default address.',
              icon: Icons.edit_location_alt_outlined,
            ),
            _HelpBlock(
              title: 'Order and payment questions',
              detail:
                  'Keep your order details handy and contact the store using the contact information shared directly by the store owner.',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
      );
}

class StorePrivacyScreen extends StatelessWidget {
  const StorePrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'Your information',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              'Your account details and delivery addresses are used to provide store services and prepare deliveries. Passwords are stored as secure hashes by the store API. This app does not save payment card numbers.',
              style: TextStyle(height: 1.55, color: AppConstants.textMuted),
            ),
            SizedBox(height: 18),
            Text(
              'Saved sign-in',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'If you opt in, sign-in details are kept in your device’s secure storage and are unlocked only after local biometric verification. You can remove them from the sign-in screen.',
              style: TextStyle(height: 1.55, color: AppConstants.textMuted),
            ),
            SizedBox(height: 18),
            Text(
              'Data requests',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'For help with account information, contact the store owner through the contact information they provide.',
              style: TextStyle(height: 1.55, color: AppConstants.textMuted),
            ),
          ],
        ),
      );
}

class _HelpBlock extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;

  const _HelpBlock({
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Icon(icon, color: AppConstants.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(detail),
          ),
        ),
      );
}
