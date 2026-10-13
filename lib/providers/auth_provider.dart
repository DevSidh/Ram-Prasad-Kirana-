import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../core/constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  late final Future<void> sessionReady;

  AuthProvider({required ApiService apiService}) : _apiService = apiService {
    sessionReady = loadSavedSession();
  }

  User? get currentUser => _currentUser;
  String? get authToken => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(AppConstants.keyToken);
    final savedUserJson = prefs.getString(AppConstants.keyUser);

    if (savedToken != null && savedUserJson != null) {
      _token = savedToken;
      _apiService.setAuthToken(savedToken);
      final savedUser = User.fromJson(jsonDecode(savedUserJson));
      _currentUser = savedUser.copyWith(
        avatarUrl: _resolveAvatarUrl(savedUser.avatarUrl),
      );
      notifyListeners();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool isAdminLogin = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        if (isAdminLogin) 'username': email.trim() else 'email': email.trim(),
        'password': password,
      });

      final token = response['token'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;
      if (token == null || userData == null) {
        throw Exception('Invalid authentication response from server');
      }

      _token = token;
      _currentUser = User(
        id: userData['id'] as String? ??
            'user-${DateTime.now().millisecondsSinceEpoch}',
        email: userData['email'] as String? ?? email,
        fullName: userData['fullName'] as String? ?? 'Customer',
        phone: userData['phone'] as String? ?? '',
        avatarUrl: _resolveAvatarUrl(userData['avatarUrl']),
        role: (userData['role'] as String? ?? 'CUSTOMER').toUpperCase(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyToken, _token!);
      await prefs.setString(
          AppConstants.keyUser, jsonEncode(_currentUser!.toJson()));

      _apiService.setAuthToken(_token!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String fullName, String email, String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/register', {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      });

      final token = response['token'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;
      if (token == null || userData == null) {
        throw Exception('Invalid registration response from server');
      }

      _token = token;
      _currentUser = User(
        id: userData['id'] as String? ??
            'user-${DateTime.now().millisecondsSinceEpoch}',
        email: userData['email'] as String? ?? email,
        fullName: userData['fullName'] as String? ?? fullName,
        phone: userData['phone'] as String? ?? phone,
        avatarUrl: _resolveAvatarUrl(userData['avatarUrl']),
        role: (userData['role'] as String? ?? 'CUSTOMER').toUpperCase(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyToken, _token!);
      await prefs.setString(
          AppConstants.keyUser, jsonEncode(_currentUser!.toJson()));

      _apiService.setAuthToken(_token!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUser);
    _apiService.clearAuthToken();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String? phone,
  }) async {
    final response = await _apiService.patch('/account/profile', {
      'fullName': fullName.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
    });
    if (response is! Map<String, dynamic> ||
        response['data'] is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid profile response.');
    }
    final user = User.fromJson(response['data'] as Map<String, dynamic>);
    final current = _currentUser;
    if (current == null || user.id != current.id) {
      throw StateError('Your sign-in session is no longer available.');
    }
    _currentUser = user.copyWith(
      avatarUrl: _resolveAvatarUrl(user.avatarUrl) ?? current.avatarUrl,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        AppConstants.keyUser, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<void> updateAvatar(Uint8List bytes, String fileName) async {
    final response = await _apiService.postFile(
      '/account/profile/avatar',
      fieldName: 'image',
      bytes: bytes,
      fileName: fileName,
    );
    if (response is! Map<String, dynamic> ||
        response['data'] is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid profile photo response.');
    }
    final data = response['data'] as Map<String, dynamic>;
    final avatarUrl = data['avatarUrl'];
    final user = _currentUser;
    if (avatarUrl is! String || user == null || data['id'] != user.id) {
      throw StateError('Your profile photo could not be updated.');
    }
    final updated = user.copyWith(
      avatarUrl: _resolveAvatarUrl(avatarUrl),
    );
    _currentUser = updated;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        AppConstants.keyUser, jsonEncode(updated.toJson()));
    notifyListeners();
  }

  String? _resolveAvatarUrl(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.toString();
    if (value.startsWith('/account/')) {
      final baseUri = Uri.parse(_apiService.baseUrl);
      final basePath = baseUri.path.endsWith('/')
          ? baseUri.path.substring(0, baseUri.path.length - 1)
          : baseUri.path;
      return baseUri
          .replace(
            path: '$basePath${uri.path}',
            query: uri.hasQuery ? uri.query : null,
          )
          .toString();
    }
    return Uri.parse(_apiService.baseUrl).resolve(value).toString();
  }
}
