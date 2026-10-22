class User {
  final String id;
  final String? profileId;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role; // CUSTOMER, ADMIN, DELIVERY_PERSON, STAFF

  User({
    required this.id,
    this.profileId,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      profileId: json['profileId'] as String?,
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'CUSTOMER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role,
    };
  }

  User copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? profileId,
  }) =>
      User(
        id: id,
        profileId: profileId ?? this.profileId,
        email: email,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
      );
}
