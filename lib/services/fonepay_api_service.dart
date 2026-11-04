import '../models/fonepay_payment_request.dart';
import '../models/pos_models.dart';
import 'api_service.dart';

class FonepayApiService {
  const FonepayApiService(this.api);
  final ApiService api;
  Future<PosSale> finalize(String id) async {
    final body = await api.post(
        '/admin/billing/fonepay/requests/${Uri.encodeComponent(id)}/finalize',
        {});
    if (body is! Map || body['sale'] is! Map<String, dynamic>) {
      throw const FormatException(
          'Payment retained. The backend did not return a finalized bill.');
    }
    final sale = PosSale.fromJson(body['sale']);
    if (sale.status != 'COMPLETED' ||
        sale.paymentStatus != 'COMPLETED' ||
        sale.paymentMethod != 'FONEPAY') {
      throw const FormatException(
          'Payment retained. Bill finalization is incomplete.');
    }
    return sale;
  }

  Future<bool> claimAutoPrint(String id) async {
    final body = await api.post(
        '/admin/billing/fonepay/requests/${Uri.encodeComponent(id)}/claim-print',
        {});
    return body is Map && body['allowed'] == true;
  }

  Future<Map<String, dynamic>> configuration() async {
    try {
      final body = await api.get('/admin/billing/fonepay/config');
      if (body is! Map || body['enabled'] is! bool) {
        throw const ApiResponseException(
            'The server returned an invalid Fonepay configuration. Update the store backend before using Fonepay.');
      }
      return Map<String, dynamic>.from(body);
    } on ApiResponseException catch (error) {
      if (error.statusCode != 404) rethrow;
      // Older deployed backends have no capability route. Do not attempt a
      // checkout, static QR, manual success or offline payment fallback.
      return {
        'enabled': false,
        'code': 'FONEPAY_BACKEND_UPDATE_REQUIRED',
        'message':
            'Fonepay is unavailable on this server. Deploy the updated store backend to Render, then complete merchant setup. You can use Cash or Pending balance meanwhile.',
      };
    }
  }

  Future<FonepayPaymentRequest> create(String saleId) async =>
      _read(await api.post(
          '/admin/billing/fonepay/sales/${Uri.encodeComponent(saleId)}/requests',
          {}));
  Future<FonepayPaymentRequest> get(String id) async => _read(await api
      .get('/admin/billing/fonepay/requests/${Uri.encodeComponent(id)}'));
  Future<FonepayPaymentRequest> verify(String id) async => _read(await api.post(
      '/admin/billing/fonepay/requests/${Uri.encodeComponent(id)}/verify', {}));
  Future<FonepayPaymentRequest> cancel(String id) async => _read(await api.post(
      '/admin/billing/fonepay/requests/${Uri.encodeComponent(id)}/cancel', {}));
  FonepayPaymentRequest _read(dynamic body) {
    if (body is! Map || body['request'] is! Map<String, dynamic>) {
      throw const FormatException(
          'The backend did not confirm the Fonepay request.');
    }
    return FonepayPaymentRequest.fromJson(
        body['request'] as Map<String, dynamic>);
  }
}
