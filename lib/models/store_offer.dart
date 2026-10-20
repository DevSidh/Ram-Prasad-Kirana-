enum OfferDiscountType { percentage, fixed }

class StoreOffer {
  final bool enabled;
  final OfferDiscountType discountType;
  final int? percent;
  final int? maxDiscount;
  final int? amount;
  final int minOrderAmount;
  final String code;
  final String id;
  final DateTime? endsAt;

  const StoreOffer({
    required this.enabled,
    this.discountType = OfferDiscountType.percentage,
    this.percent,
    this.maxDiscount,
    this.amount,
    this.minOrderAmount = 0,
    required this.code,
    required this.id,
    required this.endsAt,
  });

  factory StoreOffer.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final rawDiscountType = json['discountType'];
    final discountType = switch (rawDiscountType) {
      'PERCENTAGE' => OfferDiscountType.percentage,
      'FIXED' => OfferDiscountType.fixed,
      _ => null,
    };
    final rawPercent = _asNumber(json['percent']);
    final rawMaxDiscount = _asNumber(json['maxDiscount']);
    final rawAmount = _asNumber(json['amount']);
    final rawMinOrderAmount = _asNumber(json['minOrderAmount']);
    final code = json['code'];
    final id = json['id'];
    final rawEndsAt = json['endsAt'];
    final endsAt = rawEndsAt == null
        ? null
        : rawEndsAt is String
            ? DateTime.tryParse(rawEndsAt)
            : null;
    final validPercentage = discountType == OfferDiscountType.percentage &&
        rawPercent != null &&
        rawPercent >= 1 &&
        rawPercent <= 100 &&
        rawMaxDiscount != null &&
        rawMaxDiscount > 0 &&
        rawAmount == null;
    final validFixed = discountType == OfferDiscountType.fixed &&
        rawAmount != null &&
        rawAmount > 0 &&
        rawPercent == null &&
        rawMaxDiscount == null;
    if (enabled is! bool ||
        discountType == null ||
        (!validPercentage && !validFixed) ||
        (rawMinOrderAmount != null && rawMinOrderAmount < 0) ||
        code is! String ||
        code.trim().isEmpty ||
        id is! String ||
        id.trim().isEmpty ||
        (rawEndsAt != null && endsAt == null)) {
      throw const FormatException('The store returned invalid offer details.');
    }

    return StoreOffer(
      enabled: enabled,
      discountType: discountType,
      percent: rawPercent?.round(),
      maxDiscount: rawMaxDiscount?.round(),
      amount: rawAmount?.round(),
      minOrderAmount: rawMinOrderAmount?.round() ?? 0,
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
