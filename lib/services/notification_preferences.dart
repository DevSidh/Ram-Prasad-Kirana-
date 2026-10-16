import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const orderUpdatesKey = 'notifications_order_updates';
  static const deliveryUpdatesKey = 'notifications_delivery_updates';
  static const storeOffersKey = 'notifications_store_offers';

  static const keysByLabel = {
    'Order updates': orderUpdatesKey,
    'Delivery updates': deliveryUpdatesKey,
    'Store offers': storeOffersKey,
  };

  static const defaults = {
    orderUpdatesKey: true,
    deliveryUpdatesKey: true,
    storeOffersKey: true,
  };

  static Future<Map<String, bool>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final entry in defaults.entries)
        entry.key: preferences.getBool(entry.key) ?? entry.value,
    };
  }

  static String keyForType(String type) {
    if (type.startsWith('ORDER_')) return orderUpdatesKey;
    if (type.startsWith('DELIVERY_')) return deliveryUpdatesKey;
    return storeOffersKey;
  }

  static bool allows(String type, Map<String, bool> preferences) =>
      preferences[keyForType(type)] ?? true;
}
