class CouponQuote {
  final bool valid;
  final String? code;
  final double discount;
  final String message;

  const CouponQuote({
    required this.valid,
    required this.code,
    required this.discount,
    required this.message,
  });

  factory CouponQuote.fromJson(Map<String, dynamic> json) {
    final valid = json['valid'];
    final rawDiscount = json['discount'];
    final message = json['message'];
    final code = json['code'];
    if (valid is! bool ||
        rawDiscount is! num ||
        message is! String ||
        (code != null && code is! String)) {
      throw const FormatException(
          'The store returned an invalid coupon result.');
    }
    return CouponQuote(
      valid: valid,
      code: code is String ? code : null,
      discount: rawDiscount.toDouble(),
      message: message,
    );
  }
}
