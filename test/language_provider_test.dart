import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language choice persists and leaves unknown product text unchanged',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppLanguageProvider();
    addTearDown(provider.dispose);

    await provider.setLanguage('ne');
    expect(provider.translate('Home'), 'गृहपृष्ठ');
    expect(provider.translate('Product entered by store'), 'Product entered by store');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_language'), 'ne');
  });
}
