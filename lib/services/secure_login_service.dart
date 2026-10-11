import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SavedCredentials {
  final String username;
  final String password;

  const SavedCredentials({required this.username, required this.password});
}

class SecureLoginService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;
  final String _storageKey;

  SecureLoginService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    LocalAuthentication? localAuthentication,
    String storageKey = 'saved_customer_login',
  })  : _storage = storage,
        _localAuthentication = localAuthentication ?? LocalAuthentication(),
        _storageKey = storageKey;

  Future<bool> get hasSavedCredentials async =>
      await _storage.read(key: _storageKey) != null;

  Future<bool> get savePromptDismissed async =>
      await _storage.read(key: '${_storageKey}_save_prompt_dismissed') == 'true';

  Future<void> dismissSavePrompt() => _storage.write(
        key: '${_storageKey}_save_prompt_dismissed',
        value: 'true',
      );

  Future<void> save(String username, String password) {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode({'username': username, 'password': password}),
    );
  }

  Future<SavedCredentials?> read() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == null) return null;
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic> ||
        decoded['username'] is! String ||
        decoded['password'] is! String) {
      await clear();
      return null;
    }
    return SavedCredentials(
      username: decoded['username'] as String,
      password: decoded['password'] as String,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    await _storage.delete(key: '${_storageKey}_save_prompt_dismissed');
  }

  Future<bool> get biometricAvailable async {
    try {
      return await _localAuthentication.isDeviceSupported() &&
          await _localAuthentication.canCheckBiometrics &&
          (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    return _localAuthentication.authenticate(
      localizedReason:
          'Verify your identity to sign in to Ram Prasad General Store.',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
