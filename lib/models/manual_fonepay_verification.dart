import 'dart:convert';

/// Explicit cashier attestation, never a provider-verified payment notification.
class ManualFonepayVerification {
  const ManualFonepayVerification(
      {required this.transactionReference,
      this.provider = 'FONEPAY',
      required this.verifiedAt,
      required this.cashierId});
  static const notePrefix = 'FASTSTORE_MANUAL_FONEPAY_V1:';
  final String transactionReference;
  final String provider;

  /// New checkbox-only confirmations use an internal reference, not a bank ID.
  bool get isCashierConfirmation => transactionReference.startsWith('CASHIER-');
  final DateTime verifiedAt;
  final String cashierId;

  Map<String, dynamic> get request => {
        'verificationMethod': 'MANUAL',
        'confirmed': true,
        'transactionReference': transactionReference,
      };

  String toNote(double amount) => '$notePrefix${jsonEncode({
            'verificationMethod': 'MANUAL',
            'provider': provider,
            'transactionReference': transactionReference,
            'referenceType': isCashierConfirmation
                ? 'CASHIER_CONFIRMATION'
                : 'MERCHANT_TRANSACTION',
            'verifiedAt': verifiedAt.toUtc().toIso8601String(),
            'verifiedById': cashierId,
            'amount': amount,
            'currency': 'NPR',
          })}';

  static ManualFonepayVerification? fromNote(String? note) {
    if (note == null || !note.startsWith(notePrefix)) return null;
    try {
      final data =
          jsonDecode(note.substring(notePrefix.length)) as Map<String, dynamic>;
      if (data['verificationMethod'] != 'MANUAL') return null;
      return ManualFonepayVerification(
          provider: data['provider']?.toString() ?? 'FONEPAY',
          transactionReference: data['transactionReference'] as String,
          verifiedAt: DateTime.parse(data['verifiedAt'] as String),
          cashierId: data['verifiedById'] as String);
    } catch (_) {
      return null;
    }
  }
}
