import 'pos_models.dart';

class FonepayPaymentRequest {
  const FonepayPaymentRequest(
      {required this.id,
      required this.saleId,
      required this.invoiceNumber,
      required this.reference,
      required this.amount,
      required this.state,
      required this.environment,
      this.merchantName,
      this.qrPayload,
      this.expiresAt,
      this.failureCode});
  final String id, saleId, invoiceNumber, reference, amount, state, environment;
  final String? merchantName, qrPayload, failureCode;
  final DateTime? expiresAt;
  bool get isTest => environment != 'live';
  bool get paid => state == 'PAID' && !isTest;
  factory FonepayPaymentRequest.fromJson(Map<String, dynamic> value) {
    const required = [
      'id',
      'saleId',
      'invoiceNumber',
      'reference',
      'amount',
      'state',
      'environment'
    ];
    if (required.any((key) => value[key] is! String) ||
        !RegExp(r'^\d{1,12}\.\d{2}$').hasMatch(value['amount'] as String) ||
        value['currency'] != 'NPR' ||
        !['sandbox', 'live'].contains(value['environment'])) {
      throw const FormatException('Invalid Fonepay payment request.');
    }
    return FonepayPaymentRequest(
        id: value['id'],
        saleId: value['saleId'],
        invoiceNumber: value['invoiceNumber'],
        reference: value['reference'],
        amount: value['amount'],
        state: value['state'],
        environment: value['environment'],
        merchantName: value['merchantName'] as String?,
        qrPayload: value['qrPayload'] as String?,
        expiresAt: DateTime.tryParse(value['expiresAt'] as String? ?? ''),
        failureCode: value['failureCode'] as String?);
  }
  bool matchesPayableBill(PosSale sale, {DateTime? now}) {
    final due =
        (sale.total * 100).round() - ((sale.paidAmount ?? 0) * 100).round();
    final parts = amount.split('.');
    final minor = int.parse(parts[0]) * 100 + int.parse(parts[1]);
    return !sale.id.startsWith('local-') &&
        sale.id == saleId &&
        ['live', 'sandbox'].contains(environment) &&
        (sale.invoiceNumber ?? sale.receiptNumber) == invoiceNumber &&
        ['CHECKOUT', 'COMPLETED'].contains(sale.status) &&
        sale.paymentStatus == 'PENDING' &&
        sale.refundedAmount == 0 &&
        due > 0 &&
        due == minor &&
        ['READY', 'PENDING'].contains(state) &&
        qrPayload?.isNotEmpty == true &&
        merchantName?.isNotEmpty == true &&
        expiresAt != null &&
        expiresAt!.isAfter(now ?? DateTime.now());
  }
}
