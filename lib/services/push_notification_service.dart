import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class PushNotificationService {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  static const _webVapidKey =
      String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty;

  Future<void> enable(ApiService apiService) async {
    if (kIsWeb) {
      throw StateError(
        'Push setup is currently available on Android and iOS only. '
        'In-app notifications are available on this device.',
      );
    }
    if (!isConfigured) {
      throw StateError(
        'Push alerts need Firebase app settings. Configure the FIREBASE_* '
        'build values and platform push credentials first.',
      );
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          authDomain: _authDomain.isEmpty ? null : _authDomain,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
          iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
        ),
      );
    }

    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError(
        'Push permission is disabled. Allow notifications in your device settings.',
      );
    }

    final token = await messaging.getToken(
      vapidKey: kIsWeb && _webVapidKey.isNotEmpty ? _webVapidKey : null,
    );
    if (token == null || token.isEmpty) {
      throw StateError('Firebase did not provide a push token for this device.');
    }

    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
            _ => 'android',
          };
    await apiService.post('/account/notifications/device-token', {
      'token': token,
      'platform': platform,
    });
  }
}
