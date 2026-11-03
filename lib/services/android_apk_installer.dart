import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidApkInstaller {
  AndroidApkInstaller._();

  static const _channel = MethodChannel('faststore/app_update');

  static Future<bool> canInstallPackages() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  static Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
