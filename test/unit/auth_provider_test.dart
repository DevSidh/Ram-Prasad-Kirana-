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

class _EmailVerificationApi extends ApiService {
  _EmailVerificationApi() : super(baseUrl: 'https://store.example/api/v1');

  final requests = <String>[];
  final registrationBodies = <Map<String, dynamic>>[];

  @override
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    requests.add(endpoint);
    if (endpoint == '/auth/register') {
      registrationBodies.add(body);
      return {
        'requiresEmailVerification': true,
        'email': body['email'],
      };
    }
    if (endpoint == '/auth/email-verification/confirm') {
      return {
        'token': 'verified-session-token',
        'user': {
          'id': 'user-verified',
          'email': body['email'],
          'fullName': 'Verified Customer',
          'role': 'CUSTOMER',
        },
      };
    }
    return {'message': 'Verification code sent.'};
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
    final savedUser = jsonDecode(preferences.getString(AppConstants.keyUser)!)
        as Map<String, dynamic>;
    expect(savedUser['avatarUrl'], 'https://store.example/uploads/avatar.png');
  });

  test('saved profile photos resolve through the API on a new device',
      () async {
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

  test('malformed saved session is cleared without failing startup', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'session-token',
      AppConstants.keyUser: '{not json',
    });

    final auth = AuthProvider(apiService: _ProfileApi());
    addTearDown(auth.dispose);
    await auth.sessionReady;

    final preferences = await SharedPreferences.getInstance();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
    expect(preferences.getString(AppConstants.keyToken), isNull);
    expect(preferences.getString(AppConstants.keyUser), isNull);
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

  test('registration stays signed out until email verification completes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = _EmailVerificationApi();
    final auth = AuthProvider(apiService: api);
    addTearDown(auth.dispose);
    await auth.sessionReady;

    final registered = await auth.register(
      'New Customer',
      'customer@example.com',
      '9812345678',
      'a-long-password',
    );

    expect(registered, isTrue);
    expect(api.requests, contains('/auth/register'));
    expect(api.registrationBodies.single['phone'], '9812345678');
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.pendingVerificationEmail, 'customer@example.com');

    await auth.requestEmailVerification('customer@example.com');
    expect(api.requests.last, '/auth/email-verification/request');

    final verified = await auth.verifyEmail('customer@example.com', '123456');
    expect(verified, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUser?.email, 'customer@example.com');
    expect(auth.pendingVerificationEmail, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(AppConstants.keyToken),
      'verified-session-token',
    );
  });
}
