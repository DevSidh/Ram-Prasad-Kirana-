import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _ProfileApi extends ApiService {
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
}
