import 'package:flutter/material.dart';

import '../models/store_availability.dart';
import '../services/api_service.dart';

class StoreAvailabilityProvider extends ChangeNotifier {
  final ApiService _apiService;
  StoreAvailability? _availability;
  bool _isLoading = false;
  String? _errorMessage;

  StoreAvailabilityProvider({required ApiService apiService})
      : _apiService = apiService;

  StoreAvailability? get availability => _availability;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    try {
      final response = await _apiService.get('/store/availability');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('The store returned invalid availability.');
      }
      _availability = StoreAvailability.fromJson(response);
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setAvailability(StoreAvailability availability) {
    _availability = availability;
    _errorMessage = null;
    notifyListeners();
  }
}
