class CustomerMenuFeatures {
  const CustomerMenuFeatures(this.values);

  static const keys = <String>[
    'orders',
    'addresses',
    'savedItems',
    'buyingStreak',
    'appearance',
    'language',
    'payments',
    'notifications',
    'notificationPreferences',
    'coupons',
    'help',
    'legal',
    'deleteAccount',
  ];

  static const defaults = CustomerMenuFeatures({
    'orders': true,
    'addresses': true,
    'savedItems': true,
    'buyingStreak': true,
    'appearance': true,
    'language': true,
    'payments': true,
    'notifications': true,
    'notificationPreferences': true,
    'coupons': true,
    'help': true,
    'legal': true,
    'deleteAccount': true,
  });

  final Map<String, bool> values;

  factory CustomerMenuFeatures.fromJson(Object? value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return CustomerMenuFeatures({
      for (final key in keys) key: json[key] is bool ? json[key] as bool : true,
    });
  }

  bool isEnabled(String key) => values[key] ?? true;

  Map<String, bool> toJson() => {
        for (final key in keys) key: isEnabled(key),
      };
}
