import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshharvest_grocery/providers/language_provider.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/models/admin_models.dart';
import 'package:freshharvest_grocery/screens/admin/admin_restock_screen.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart' as billing;
import 'package:freshharvest_grocery/theme/app_colors.dart';
import 'package:freshharvest_grocery/widgets/billing_language_switch.dart';
import 'package:freshharvest_grocery/widgets/readable_product_card.dart';

class _StockApi extends ApiService {
  Map<String, dynamic>? submitted;
  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    expect(endpoint, '/admin/products/rice/restock');
    submitted = body;
    return {
      'product': {
        'id': 'rice',
        'name': 'Grandpa rice',
        'price': 200,
        'stock': 8,
        'unitLabel': '1 pc'
      }
    };
  }
}

void main() {
  tearDown(() => BillingStrings.languageCode = 'en');
  for (final language in ['en', 'ne']) {
    for (final dark in [false, true]) {
      for (final size in [const Size(360, 800), const Size(1366, 768)]) {
        testWidgets(
            '$language ${dark ? 'dark' : 'light'} large controls and invoice-free stock entry at $size',
            (tester) async {
          AppColors.windowsAdminDarkTheme = dark;
          addTearDown(AppColors.clearWindowsAdminTheme);
          SharedPreferences.setMockInitialValues({});
          late AppLanguageProvider provider;
          await tester.runAsync(() async {
            provider = AppLanguageProvider();
            await provider.setLanguage(language);
          });
          addTearDown(provider.dispose);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            final loader = FontLoader('FastStoreDevanagari')
              ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'));
            await loader.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
          });
          final api = _StockApi();
          final product = AdminProduct.fromJson({
            'id': 'rice',
            'name': 'Grandpa rice',
            'price': 200,
            'stock': 5,
            'unitLabel': '1 pc',
            'lowStockThreshold': 7
          });
          final boundary = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: boundary,
              child: ChangeNotifierProvider.value(
                  value: provider,
                  child: MaterialApp(
                    locale: Locale(language),
                    supportedLocales: const [Locale('en'), Locale('ne')],
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    theme: billing.AppTheme.data,
                    home: Scaffold(
                        body: Column(children: [
                      const BillingLanguageSwitch(),
                      Expanded(
                          child: SingleChildScrollView(
                              child: Builder(
                                  builder: (context) => ReadableProductCard(
                                      product: product,
                                      onAddStock: () => showAddStockDialog(
                                          context,
                                          AdminApiService(api),
                                          product),
                                      onEdit: () {},
                                      onSetActive: () {}))))
                    ])),
                  ))));
          await tester.pumpAndSettle();
          expect(find.text('English'), findsOneWidget);
          expect(find.text('नेपाली'), findsOneWidget);
          final button =
              find.text(language == 'ne' ? 'मौज्दात थप्नुहोस्' : 'Add stock');
          expect(
              tester
                  .getSize(find.ancestor(
                      of: button,
                      matching: find.byWidgetPredicate(
                          (widget) => widget is FilledButton)))
                  .height,
              greaterThanOrEqualTo(56));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('Grandpa rice'), findsWidgets);
          expect(
              find.text(language == 'ne'
                  ? 'आपूर्तिकर्ताको बिल वा बिल नम्बर चाहिँदैन।'
                  : 'No supplier bill or invoice number is required.'),
              findsOneWidget);
          final field = find.byWidgetPredicate((w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  (language == 'ne' ? 'प्राप्त परिमाण' : 'Quantity received'));
          await tester.enterText(field, '3');
          final mfg = find.text(
              language == 'ne' ? 'उत्पादन मिति' : 'Manufacture date (MFG)');
          await tester.ensureVisible(mfg);
          await tester.pumpAndSettle();
          await tester.tap(mfg);
          await tester.pumpAndSettle();
          await tester.tap(find.text(MaterialLocalizations.of(
                  tester.element(find.byType(DatePickerDialog)))
              .okButtonLabel));
          await tester.pumpAndSettle();
          final noExpiry = find.text(language == 'ne'
              ? 'यो सामानको म्याद हुँदैन'
              : 'This product does not expire');
          await tester.ensureVisible(noExpiry);
          await tester.pumpAndSettle();
          await tester.tap(noExpiry);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (language == 'ne') {
            await tester.runAsync(() async {
              final image = await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final png =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final directory = Directory('tmp/bilingual-preview')
                ..createSync(recursive: true);
              await File(
                      '${directory.path}/stock-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png')
                  .writeAsBytes(png!.buffer.asUint8List());
              image.dispose();
            });
          }
          final add = find.text(BillingStrings.tr('Add to stock'));
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(api.submitted?['quantity'], 3);
          expect(api.submitted?['noExpiry'], true);
          expect(api.submitted!.containsKey('invoiceNumber'), false);
          expect(api.submitted!.containsKey('supplierId'), false);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
      }
    }
  }
}
