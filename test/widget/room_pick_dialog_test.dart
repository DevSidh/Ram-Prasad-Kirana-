import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/models/room_inventory.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart';
import 'package:freshharvest_grocery/widgets/room_pick_dialog.dart';

void main() {
  for (final language in ['en', 'ne']) {
    for (final size in [const Size(360, 800), const Size(1366, 900)]) {
      testWidgets(
          'room picker is readable and cancel creates no allocation: $language $size',
          (tester) async {
        await tester.runAsync(() => BillingStrings.load());
        BillingStrings.languageCode = language;
        addTearDown(() => BillingStrings.languageCode = 'en');
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = RoomInventorySnapshot.fromJson({
          'rooms': [
            {'id': 'a', 'name': 'Main store', 'number': '01', 'active': true}
          ],
          'stocks': [
            {'productId': 'tea', 'roomId': 'a', 'quantity': 6}
          ],
          'totals': [
            {'productId': 'tea', 'total': 10, 'available': 10}
          ],
          'capturedAt': '2026-11-06T00:00:00Z',
        });
        List<RoomPick>? result;
        var done = false;
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.data,
            home: Builder(
                builder: (context) => Scaffold(
                    body: FilledButton(
                        onPressed: () async {
                          result = await showDialog<List<RoomPick>>(
                              context: context,
                              builder: (_) => RoomPickDialog(
                                      snapshot: snapshot,
                                      products: const [
                                        PosProduct(
                                            id: 'tea',
                                            name: 'Fixture tea',
                                            sku: 'TEA',
                                            barcode: null,
                                            price: 10,
                                            unitLabel: 'pcs',
                                            available: 10)
                                      ],
                                      requiredQuantities: const {
                                        'tea': 5
                                      }));
                          done = true;
                        },
                        child: const Text('Open'))))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Fixture tea'), findsOneWidget);
        expect(find.byType(EditableText), findsOneWidget,
            reason: 'Assigned products must not offer an Unassigned bucket.');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(BillingStrings.tr('Cancel / Back')));
        await tester.pumpAndSettle();
        expect(done, isTrue);
        expect(result, isNull);
        expect(snapshot.quantity('tea', 'a'), 6);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
