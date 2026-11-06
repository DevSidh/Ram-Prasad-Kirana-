import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => BillingStrings.languageCode = 'en');
  test('billing catalog is valid UTF-8 and English remains exact', () async {
    await BillingStrings.load();
    final source = jsonDecode(
            await rootBundle.loadString('assets/translations/billing_ne.json'))
        as Map;
    for (final entry in source.entries) {
      expect(entry.value, isA<String>());
      expect((entry.value as String).contains('\uFFFD'), false,
          reason: entry.key as String);
      expect(BillingStrings.tr(entry.key as String), entry.key);
    }
    BillingStrings.languageCode = 'ne';
    expect(BillingStrings.tr('Create bill'), 'बिल बनाउनुहोस्');
    expect(BillingStrings.tr('INVOICE MANAGEMENT'), 'बिल व्यवस्थापन');
    expect(BillingStrings.tr('Customer selected: Grandpa Sharma'),
        'छानिएको ग्राहक: Grandpa Sharma');
    expect(BillingStrings.tr('POS-2026-1105'), 'POS-2026-1105');
    expect(BillingStrings.tr('Custom shop product 500g'),
        'Custom shop product 500g');
    expect(BillingStrings.tr('Rs. 235.50'), 'रु. 235.50');
    expect(BillingStrings.tr('3.5 kg'), '3.5 किलोग्राम');
  });
  test(
      'Nepali choice is restored on reopening without overwriting a newer selection',
      () async {
    SharedPreferences.setMockInitialValues({'app_language': 'ne'});
    final provider = AppLanguageProvider();
    final dataLocale = Intl.defaultLocale;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(provider.languageCode, 'ne');
    expect(BillingStrings.isNepali, true);
    expect(Intl.defaultLocale, dataLocale);
    expect(DateFormat('yyyy-MM-dd', 'en').format(DateTime(2026, 11, 6)),
        '2026-11-06');
    await provider.setLanguage('en');
    final reopened = AppLanguageProvider();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reopened.languageCode, 'en');
    expect(BillingStrings.tr('Create bill'), 'Create bill');
    provider.dispose();
    reopened.dispose();
  });
}
