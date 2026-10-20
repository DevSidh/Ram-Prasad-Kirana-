import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/models/store_offer.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/services/shown_today_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parses the backend offer fields and rejects expired offers', () {
    final offer = StoreOffer.fromJson({
      'enabled': true,
      'discountType': 'PERCENTAGE',
      'percent': 15,
      'maxDiscount': '200',
      'amount': null,
      'minOrderAmount': 500,
      'code': 'save15',
      'id': 'coupon-1',
      'endsAt': '2026-10-21T00:00:00.000Z',
    });

    expect(offer.percent, 15);
    expect(offer.maxDiscount, 200);
    expect(offer.code, 'SAVE15');
    expect(offer.isAvailableAt(DateTime.utc(2026, 10, 20)), isTrue);
    expect(offer.isAvailableAt(DateTime.utc(2026, 10, 22)), isFalse);
  });

  test('parses fixed-amount offers without presenting them as percentages', () {
    final offer = StoreOffer.fromJson({
      'enabled': true,
      'discountType': 'FIXED',
      'percent': null,
      'maxDiscount': null,
      'amount': 50,
      'minOrderAmount': 0,
      'code': 'diwali50',
      'id': 'coupon-diwali',
      'endsAt': null,
    });

    expect(offer.discountType, OfferDiscountType.fixed);
    expect(offer.amount, 50);
    expect(offer.percent, isNull);
    expect(offer.minOrderAmount, 0);
    expect(offer.code, 'DIWALI50');
  });

  test('stores each offer id against the local date it was shown', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = ShownTodayStore(preferences);
    final today = DateTime(2026, 10, 20, 12);

    expect(await store.wasShownToday('coupon-1', now: today), isFalse);
    await store.markShownToday('coupon-1', now: today);
    expect(await store.wasShownToday('coupon-1', now: today), isTrue);
    expect(
      await store.wasShownToday(
        'coupon-1',
        now: DateTime(2026, 10, 21, 12),
      ),
      isFalse,
    );
    expect(await store.wasShownToday('coupon-2', now: today), isFalse);
  });

  test('a new install defaults to light while saved themes are restored',
      () async {
    final firstInstall = ThemeProvider();
    expect(firstInstall.themeMode, ThemeMode.light);
    expect(AppConstants.isDarkTheme, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(firstInstall.themeMode, ThemeMode.light);
    firstInstall.dispose();

    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final returningUser = ThemeProvider();
    await Future<void>.delayed(Duration.zero);
    expect(returningUser.themeMode, ThemeMode.dark);
    returningUser.dispose();
    AppConstants.setDarkTheme(false);
  });

  test('claimed offer code is held in cart state until checkout validation',
      () {
    final cart = CartProvider();
    addTearDown(cart.dispose);

    cart.suggestCouponCode('festival50');
    expect(cart.suggestedCouponCode, 'FESTIVAL50');
    cart.clearSuggestedCouponCode('other');
    expect(cart.suggestedCouponCode, 'FESTIVAL50');
    cart.clearSuggestedCouponCode('festival50');
    expect(cart.suggestedCouponCode, isNull);
  });
}
