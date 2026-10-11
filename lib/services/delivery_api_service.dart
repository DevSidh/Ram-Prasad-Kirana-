import '../models/delivery_models.dart';
import 'api_service.dart';

class DeliveryApiService {
  final ApiService _api;

  DeliveryApiService(this._api);

  Future<DeliveryProfile> getProfile() async {
    final response = await _api.get('/delivery/profile');
    if (response is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid delivery profile.');
    }
    return DeliveryProfile.fromJson(response);
  }

  Future<DeliveryAssignmentPage> getAssignments({String? status}) async {
    final response = await _api.get(
      '/delivery/assignments',
      queryParams: {if (status != null) 'status': status},
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid delivery list.');
    }
    return DeliveryAssignmentPage.fromJson(response);
  }

  Future<void> setAvailability(bool isAvailable) async {
    await _api.patch('/delivery/availability', {'isAvailable': isAvailable});
  }

  Future<void> updateAssignment(
    String id,
    String status, {
    String? reason,
    String? recipientName,
    double? cashCollected,
  }) async {
    await _api.patch('/delivery/assignments/$id', {
      'status': status,
      if (reason != null) 'reason': reason,
      if (recipientName != null) 'recipientName': recipientName,
      if (cashCollected != null) 'cashCollected': cashCollected,
    });
  }
}
