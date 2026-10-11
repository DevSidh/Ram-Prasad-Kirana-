class Address {
  final String id;
  final String title; // Home, Work, Other
  final String fullName;
  final String phone;
  final String province;
  final String city;
  final String street;
  final String? landmark;
  final String? instructions;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.title,
    required this.fullName,
    required this.phone,
    this.province = 'Bagmati',
    required this.city,
    required this.street,
    this.landmark,
    this.instructions,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['label'] ?? 'Home').toString(),
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      province: (json['province'] ?? '').toString(),
      city: json['city']?.toString() ?? '',
      street: (json['street'] ?? json['addressLine1'] ?? '').toString(),
      landmark: (json['landmark'] ?? json['addressLine2'])?.toString(),
      instructions: json['instructions'],
      isDefault: json['isDefault'] == true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fullName': fullName,
      'phone': phone,
      'province': province,
      'city': city,
      'street': street,
      'landmark': landmark,
      'instructions': instructions,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map<String, dynamic> toApiJson() => {
        'title': title,
        'fullName': fullName,
        'phone': phone,
        'province': province,
        'city': city,
        'street': street,
        'landmark': landmark,
        'instructions': instructions,
        'isDefault': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      };
}
