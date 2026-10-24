import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool failReadAll = false;
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
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
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
    if (endpoint == '/account/notifications/read-all') {
      if (failReadAll) {
        throw StateError('Read-all request failed.');
      }
      for (final notification in notifications) {
        notification['isRead'] = true;
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coupon notification offers to copy its code', (tester) async {
    final copiedValues = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedValues.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.com',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
    });
    final api = _NotificationsApi()
      ..notifications.add({
        'id': 'offer-1',
        'title': 'Coupon alert',
        'body': 'Use this offer at checkout.',
        'type': 'PROMOTIONAL',
        'metadata': {'couponCode': 'SAVE10'},
        'isRead': false,
        'createdAt': '2026-10-12T06:00:00.000Z',
      });
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
    await tester.tap(find.text('FASTSTORE'));
    await tester.pumpAndSettle();

    expect(find.text('Coupon SAVE10 is ready to use at checkout.'),
        findsOneWidget);
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    expect(find.text('Coupon SAVE10 copied.'), findsOneWidget);
    expect(copiedValues, ['SAVE10']);
  });

  testWidgets('notification list stays available when mark-all-read fails',
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

    final api = _NotificationsApi()..failReadAll = true;
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
    expect(
      find.text(
          'Could not mark notifications as read. Showing updates anyway.'),
      findsOneWidget,
    );
    expect(find.text('Notifications could not load'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening notifications marks all read before deleting',
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
    expect(api.patchedEndpoint, '/account/notifications/read-all');
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

  testWidgets('notification preferences filter the in-app activity list',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.com',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
      'notifications_order_updates': false,
      'notifications_store_offers': false,
    });

    final api = _NotificationsApi()
      ..notifications.addAll([
        {
          'id': 'delivery-1',
          'title': 'Delivery notice',
          'body': 'Your order is with the rider.',
          'type': 'DELIVERY_UPDATED',
          'isRead': false,
          'createdAt': '2026-10-12T06:00:00.000Z',
        },
        {
          'id': 'offer-1',
          'title': 'Store offer',
          'body': 'A new offer is available.',
          'type': 'PROMOTIONAL',
          'isRead': false,
          'createdAt': '2026-10-12T06:00:00.000Z',
        },
      ]);
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

    expect(find.text('Delivery notice'), findsOneWidget);
    expect(find.text('Order update'), findsNothing);
    expect(find.text('Store offer'), findsNothing);
  });
}
