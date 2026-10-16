import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _ProfileApi extends ApiService {
  _ProfileApi() : super(baseUrl: 'https://store.example/api/v1');

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    return {
      'data': {
        'id': 'user-1',
        'fullName': body['fullName'],
        'email': 'customer@example.com',
        'phone': body['phone'],
        'role': 'CUSTOMER',
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile edits preserve and persist the existing avatar URL', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'session-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'user-1',
        'email': 'customer@example.com',
        'fullName': 'Customer',
        'phone': null,
        'avatarUrl': 'https://store.example/uploads/avatar.png',
        'role': 'CUSTOMER',
      }),
    });

    final auth = AuthProvider(apiService: _ProfileApi());
    addTearDown(auth.dispose);
    await auth.sessionReady;

    await auth.updateProfile(fullName: 'Updated Customer', phone: null);

    expect(
      auth.currentUser?.avatarUrl,
      'https://store.example/uploads/avatar.png',
    );
    final preferences = await SharedPreferences.getInstance();
    final savedUser =
        jsonDecode(preferences.getString(AppConstants.keyUser)!)
            as Map<String, dynamic>;
    expect(savedUser['avatarUrl'], 'https://store.example/uploads/avatar.png');
  });

  test('saved profile photos resolve through the API on a new device', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'session-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'user-1',
        'email': 'customer@example.com',
        'fullName': 'Customer',
        'phone': null,
        'avatarUrl': '/account/profile/avatar/user-1?v=123',
        'role': 'CUSTOMER',
      }),
    });

    final auth = AuthProvider(apiService: _ProfileApi());
    addTearDown(auth.dispose);
    await auth.sessionReady;

    expect(
      auth.currentUser?.avatarUrl,
      'https://store.example/api/v1/account/profile/avatar/user-1?v=123',
    );
    expect(auth.authToken, 'session-token');
  });

  test('logout clears the active session and persisted account data', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'session-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'user-1',
        'email': 'customer@example.com',
        'fullName': 'Customer',
        'role': 'CUSTOMER',
      }),
    });

    final auth = AuthProvider(apiService: _ProfileApi());
    addTearDown(auth.dispose);
    await auth.sessionReady;

    await auth.logout();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(AppConstants.keyToken), isFalse);
    expect(preferences.containsKey(AppConstants.keyUser), isFalse);
  });
}
