import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_preferences.dart';
import '../../widgets/store_animation.dart';

class PaymentPreferenceScreen extends StatelessWidget {
  const PaymentPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Payment methods'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context
                .tr('Cash on delivery is currently the only payment method.'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'eSewa and Khalti are not available yet. Payment is confirmed by the store when your order is delivered.',
            ),
            style: TextStyle(color: AppConstants.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: const Icon(
                Icons.payments_outlined,
                color: AppConstants.primary,
              ),
              title: Text(
                context.tr('Cash on delivery'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                context.tr('Pay the delivery person when your order arrives.'),
              ),
              trailing: const Icon(
                Icons.check_circle,
                color: AppConstants.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  Map<String, bool> _values = const {};
  final Set<String> _savingKeys = {};
  bool _loading = true;
  String? _error;

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
      final values = await NotificationPreferences.load();
      if (!mounted) return;
      setState(() {
        _values = values;
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

  Future<void> _setValue(String label, bool value) async {
    final key = NotificationPreferences.keysByLabel[label];
    if (key == null || _savingKeys.contains(key)) return;
    setState(() => _savingKeys.add(key));
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
      if (mounted) setState(() => _values = {..._values, key: value});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('Could not save this notification preference:')} $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Notification Preferences'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? StorePageError(
                  title: context.tr('Preferences unavailable'),
                  message: _error!,
                  retryLabel: context.tr('Try again'),
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      context.tr('Choose the updates shown in your inbox'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'These filters are saved on this device and only affect the in-app notification list. To turn off push alerts, use your device notification settings.',
                      ),
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final entry
                        in NotificationPreferences.keysByLabel.entries)
                      Card(
                        child: SwitchListTile.adaptive(
                          value: _values[entry.value] ?? true,
                          onChanged: _savingKeys.contains(entry.value)
                              ? null
                              : (value) => _setValue(entry.key, value),
                          title: Text(context.tr(entry.key)),
                          activeThumbColor: AppConstants.primary,
                          secondary: _savingKeys.contains(entry.value)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
    );
  }
}

class StoreHelpScreen extends StatelessWidget {
  const StoreHelpScreen({super.key});

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not open this app.'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Could not open this app.')} $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Store help'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('How can we help?'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _HelpAction(
            title: context.tr('Open store in Maps'),
            detail: '26.743218, 85.918854 · Ram Prasad General Store',
            icon: Icons.map_outlined,
            onTap: () => _openLink(
              context,
              Uri.parse('https://maps.app.goo.gl/VhZVyKZ6VEDCcyZf6'),
            ),
          ),
          _HelpAction(
            title: context.tr('Call store'),
            detail: '9824824813',
            icon: Icons.call_outlined,
            onTap: () =>
                _openLink(context, Uri(scheme: 'tel', path: '9824824813')),
          ),
          _HelpBlock(
            title: context.tr('Delivery area'),
            detail: context.tr(
              'Delivery is available within 10 km of Ram Prasad General Store. Add your full ward and street details, and place a map pin within the service area.',
            ),
            icon: Icons.location_on_outlined,
          ),
          _HelpBlock(
            title: context.tr('Update an address'),
            detail: context.tr(
              'Open Account → Delivery Addresses to add, edit, remove, or choose your default address.',
            ),
            icon: Icons.edit_location_alt_outlined,
          ),
          _HelpBlock(
            title: context.tr('Order and payment questions'),
            detail: context.tr(
              'Keep your order details handy and contact the store using the contact information shared directly by the store owner.',
            ),
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }
}

class StorePrivacyScreen extends StatelessWidget {
  const StorePrivacyScreen({super.key});

  Future<void> _openPublicPage(BuildContext context, String path) async {
    final uri = Uri.parse(AppConstants.apiBaseUrl).replace(path: '/$path');
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not open this app.'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Could not open this app.')} $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Privacy'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('Your information'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Your account details and delivery addresses are used to provide store services and prepare deliveries. Passwords are stored as secure hashes by the store API. This app does not save payment card numbers.',
            ),
            style: TextStyle(height: 1.55, color: AppConstants.textMuted),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Saved sign-in'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'If you opt in, sign-in details are kept in your device’s secure storage. You can use biometrics to sign in when they are available on your device, or continue with saved sign-in otherwise. You can remove saved sign-in from the sign-in screen.',
            ),
            style: TextStyle(height: 1.55, color: AppConstants.textMuted),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Data requests'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'You can request account deletion in the app or by contacting the store from your registered email address. Active orders must be completed or cancelled first.',
            ),
            style: TextStyle(height: 1.55, color: AppConstants.textMuted),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text(context.tr('Read full privacy policy')),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openPublicPage(context, 'privacy-policy'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(context.tr('Open account deletion page')),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openPublicPage(context, 'account-deletion'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ramprasad.faststore@gmail.com · +977 9824824813',
            style: TextStyle(height: 1.55, color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
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

class _HelpAction extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _HelpAction({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          onTap: onTap,
          leading: Icon(icon, color: AppConstants.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(detail),
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
        ),
      );
}
