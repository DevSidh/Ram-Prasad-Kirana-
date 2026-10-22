import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AdminOrderNotificationService {
  const AdminOrderNotificationService();

  static const MethodChannel _channel =
      MethodChannel('faststore/admin_order_alerts');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      debugPrint('Admin order system notifications are not available.');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Could not request order notification permission: $error');
      return false;
    }
  }

  Future<bool> showNewOrder(String orderNumber) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'showNewOrder',
            {'orderNumber': orderNumber},
          ) ??
          false;
    } on MissingPluginException {
      debugPrint('Admin order system notifications are not available.');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Could not show new-order notification: $error');
      return false;
    }
  }
}
