import 'package:shared_preferences/shared_preferences.dart';

class ShownTodayStore {
  static const loginOfferPendingKey = 'login_offer_popup_pending';

  final SharedPreferences _preferences;

  const ShownTodayStore(this._preferences);

  Future<bool> wasShownToday(String offerId, {DateTime? now}) async {
    return _preferences.getString(_offerKey(offerId)) == _dayKey(now);
  }

  Future<void> markShownToday(String offerId, {DateTime? now}) async {
    await _preferences.setString(_offerKey(offerId), _dayKey(now));
  }

  static Future<void> markLoginOfferPending() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(loginOfferPendingKey, true);
  }

  static String _offerKey(String offerId) => 'shown_offer_$offerId';

  static String _dayKey(DateTime? now) {
    final date = now ?? DateTime.now();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
