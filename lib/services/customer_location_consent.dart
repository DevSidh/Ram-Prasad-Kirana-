import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

class CustomerLocationConsent {
  static String _enabledKey(String userId) =>
      'customer_live_location_enabled_$userId';
  static String _askedKey(String userId) =>
      'customer_live_location_asked_$userId';

  static Future<bool> isEnabled(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey(userId)) ?? false;
  }

  static Future<void> requestAfterSignIn(
    BuildContext context, {
    required String userId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_askedKey(userId)) ?? false) return;
    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share your location during delivery?'),
        content: const Text(
          'If you allow it, your live location is shared only with the delivery '
          'partner assigned to an order while it is out for delivery. Sharing '
          'stops when the delivery ends. You can decline and still place orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    var permission = LocationPermission.denied;
    if (accepted == true && context.mounted) {
      permission = await LocationService().requestBackgroundSharingPermission();
      if ((permission == LocationPermission.whileInUse ||
              permission == LocationPermission.deniedForever) &&
          context.mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Allow background location'),
            content: const Text(
              'To keep sharing during an active delivery when FastStore is '
              'not on screen, choose “Allow all the time” in app location settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (openSettings == true) {
          await Geolocator.openAppSettings();
          permission = await Geolocator.checkPermission();
        }
      }
    }
    final enabled = permission == LocationPermission.always;
    await preferences.setBool(_enabledKey(userId), enabled);
    await preferences.setBool(_askedKey(userId), true);
  }
}
