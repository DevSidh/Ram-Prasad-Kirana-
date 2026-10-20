import '../models/store_offer.dart';
import 'api_service.dart';

class OfferService {
  final ApiService _api;

  OfferService(this._api);

  Future<StoreOffer?> getActiveOffer() async {
    final response = await _api.get('/coupons/offer');
    if (response is! Map<String, dynamic> || !response.containsKey('offer')) {
      throw const FormatException(
          'The store returned an invalid offer result.');
    }
    final offer = response['offer'];
    if (offer == null) return null;
    if (offer is! Map<String, dynamic>) {
      throw const FormatException('The store returned invalid offer details.');
    }
    return StoreOffer.fromJson(offer);
  }
}
