import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/manual_fonepay_verification.dart';

void main() {
  test(
      'manual verification audit round-trips identity, reference, amount and time',
      () {
    final verification = ManualFonepayVerification(
        transactionReference: 'BANK-001',
        verifiedAt: DateTime.utc(2026, 11, 5, 9),
        cashierId: 'cashier-1');
    final note = verification.toNote(214.70);
    final data =
        jsonDecode(note.substring(ManualFonepayVerification.notePrefix.length));
    expect(data['verificationMethod'], 'MANUAL');
    expect(data['currency'], 'NPR');
    expect(data['amount'], 214.7);
    final restored = ManualFonepayVerification.fromNote(note)!;
    expect(restored.cashierId, 'cashier-1');
    expect(restored.transactionReference, 'BANK-001');
    expect(restored.verifiedAt, verification.verifiedAt);
  });
  test('ordinary payment notes are not claimed as manual Fonepay verification',
      () {
    expect(ManualFonepayVerification.fromNote(null), isNull);
    expect(ManualFonepayVerification.fromNote('Payment received'), isNull);
    expect(
        ManualFonepayVerification.fromNote(
            '${ManualFonepayVerification.notePrefix}broken'),
        isNull);
  });
}
