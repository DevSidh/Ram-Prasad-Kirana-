import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/screens/notifications/notifications_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _NotificationsApi extends ApiService {
  String? deletedEndpoint;
  String? patchedEndpoint;
  bool failDelete = false;
  final List<Map<String, dynamic>> notifications = [
    {
      'id': 'notification-1',
      'title': 'Order update',
      'body': 'Your order is on its way.',
      'type': 'ORDER_SHIPPED',
      'isRead': false,
      'createdAt': '2026-10-12T06:00:00.000Z',
    },
  ];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    return {
      'data': notifications,
      'pushAvailable': false,
    };
  }

  @override
  Future<dynamic> delete(String endpoint) async {
    deletedEndpoint = endpoint;
    if (failDelete) throw Exception('Delete request failed.');
    if (endpoint == '/account/notifications') {
      notifications.clear();
    } else {
      final id = endpoint.split('/').last;
      notifications.removeWhere((item) => item['id'] == id);
    }
  }

  @override
  Future<dynamic> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    patchedEndpoint = endpoint;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notification delete confirms and does not mark it read',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.com',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
    });

    final api = _NotificationsApi();
    final auth = AuthProvider(apiService: api);
    final theme = ThemeProvider();
    addTearDown(auth.dispose);
    addTearDown(theme.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order update'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete notification'));
    await tester.pumpAndSettle();
    expect(find.text('Delete notification?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(api.deletedEndpoint, '/account/notifications/notification-1');
    expect(api.patchedEndpoint, isNull);
    expect(api.notifications, isEmpty);
    expect(find.text('Order update'), findsNothing);
    expect(find.text('Nothing new yet'), findsOneWidget);
    expect((await api.get('/account/notifications'))['data'], isEmpty);
  });

  testWidgets('failed notification deletion restores the activity item',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.com',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
    });

    final api = _NotificationsApi()..failDelete = true;
    final auth = AuthProvider(apiService: api);
    final theme = ThemeProvider();
    addTearDown(auth.dispose);
    addTearDown(theme.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Order update'), findsOneWidget);
    expect(find.text('Delete request failed.'), findsOneWidget);
  });

  testWidgets('delete all notifications clears the signed-in users list',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.com',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
    });

    final api = _NotificationsApi();
    final auth = AuthProvider(apiService: api);
    final theme = ThemeProvider();
    addTearDown(auth.dispose);
    addTearDown(theme.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete all notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all notifications?'), findsOneWidget);
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();

    expect(api.deletedEndpoint, '/account/notifications');
    expect(find.text('Order update'), findsNothing);
    expect(find.text('Nothing new yet'), findsOneWidget);
  });
}
