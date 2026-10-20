class StoreOffer {
  final bool enabled;
  final int percent;
  final int maxDiscount;
  final String code;
  final String id;
  final DateTime? endsAt;

  const StoreOffer({
    required this.enabled,
    required this.percent,
    required this.maxDiscount,
    required this.code,
    required this.id,
    required this.endsAt,
  });

  factory StoreOffer.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final rawPercent = _asNumber(json['percent']);
    final rawMaxDiscount = _asNumber(json['maxDiscount']);
    final code = json['code'];
    final id = json['id'];
    final rawEndsAt = json['endsAt'];
    final endsAt = rawEndsAt == null
        ? null
        : rawEndsAt is String
            ? DateTime.tryParse(rawEndsAt)
            : null;
    if (enabled is! bool ||
        rawPercent == null ||
        rawPercent < 1 ||
        rawPercent > 100 ||
        rawMaxDiscount == null ||
        rawMaxDiscount <= 0 ||
        code is! String ||
        code.trim().isEmpty ||
        id is! String ||
        id.trim().isEmpty ||
        (rawEndsAt != null && endsAt == null)) {
      throw const FormatException('The store returned invalid offer details.');
    }

    return StoreOffer(
      enabled: enabled,
      percent: rawPercent.round(),
      maxDiscount: rawMaxDiscount.round(),
      code: code.trim().toUpperCase(),
      id: id.trim(),
      endsAt: endsAt,
    );
  }

  bool isAvailableAt(DateTime now) =>
      enabled && (endsAt == null || endsAt!.isAfter(now));
}

num? _asNumber(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
