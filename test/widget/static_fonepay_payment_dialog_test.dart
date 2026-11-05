import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/widgets/static_fonepay_payment_dialog.dart';
import '../fixtures/fonepay_fixture.dart';

void main() {
  late int confirmations, prints;
  late Completer<PosSale> saved;
  bool failPrint = false;
  PosSale? closedSale;
  setUp(() {
    confirmations = 0;
    prints = 0;
    saved = Completer<PosSale>();
    failPrint = false;
    closedSale = null;
  });

  Future<void> open(WidgetTester tester,
      {bool configured = true, String cashier = 'cashier-1'}) async {
    saved = Completer<PosSale>();
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Open payment'),
                    onPressed: () async {
                      closedSale = await showDialog<PosSale>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => StaticFonepayPaymentDialog(
                                amount: 113.01,
                                cashierId: cashier,
                                qrAsset: configured
                                    ? 'assets/images/personal_bank_qr.jpeg'
                                    : '',
                                onVerified: (verification) {
                                  confirmations++;
                                  expect(verification.cashierId, 'cashier-1');
                                  expect(verification.isCashierConfirmation,
                                      isTrue);
                                  return saved.future;
                                },
                                onPrint: (sale) async {
                                  prints++;
                                  expect(sale.total, 113.01);
                                  if (failPrint) {
                                    throw StateError('Printer fixture offline');
                                  }
                                  return true;
                                },
                              ));
                    })))));
    await tester.tap(find.text('Open payment'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  Future<void> verify(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  testWidgets(
      'QR and amount remain pending until a cashier explicitly confirms',
      (tester) async {
    await open(tester);
    expect(find.text('113.01'), findsOneWidget);
    expect(find.text('Waiting for cashier to confirm payment received.'),
        findsOneWidget);
    expect(find.text('Scan using Fonepay and enter the exact amount.'),
        findsOneWidget);
    expect(confirmations, 0);
    expect(prints, 0);
    await tester.tap(find.text('Cancel / Back'));
    await tester.pumpAndSettle();
    expect(confirmations, 0);
    expect(closedSale, isNull);
  });

  testWidgets(
      'confirmation is single-flight and print failure reprints the saved bill',
      (tester) async {
    failPrint = true;
    await open(tester);
    await verify(tester);
    final button = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton, 'Payment Verified — Create & Print Bill'));
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(confirmations, 1);
    saved.complete(fonepayFixtureSale(
        paymentMethod: 'FONEPAY',
        paymentStatus: 'COMPLETED',
        paidAmount: 113.01));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(prints, 1);
    expect(find.textContaining('Printing failed'), findsOneWidget);
    failPrint = false;
    final reprint = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reprint Bill'));
    reprint.onPressed!();
    reprint.onPressed!();
    await tester.pumpAndSettle();
    expect(confirmations, 1);
    expect(prints, 2);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(closedSale?.invoiceNumber, fonepayFixtureSale().invoiceNumber);
    expect(closedSale?.autoPrintAllowed, isFalse);
  });

  testWidgets('a replayed saved bill never triggers a second automatic print',
      (tester) async {
    await open(tester);
    await verify(tester);
    await tester.tap(find.text('Payment Verified — Create & Print Bill'));
    saved.complete(fonepayFixtureSale(
            paymentMethod: 'FONEPAY',
            paymentStatus: 'COMPLETED',
            paidAmount: 113.01)
        .withAutoPrintAllowed(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(confirmations, 1);
    expect(prints, 0);
    expect(find.text('Reprint Bill'), findsOneWidget);
  });

  testWidgets('unconfigured QR cannot be used to mark a payment paid',
      (tester) async {
    await open(tester, configured: false);
    await verify(tester);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(
                FilledButton, 'Payment Verified — Create & Print Bill'))
            .onPressed,
        isNull);
    expect(confirmations, 0);
    expect(prints, 0);
  });
}
