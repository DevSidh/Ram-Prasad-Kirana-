import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/widgets/unread_notification_indicator.dart';

void main() {
  testWidgets('shows a red dot when the account has an unread notification',
      (tester) async {
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'data': [
                {'isRead': true},
              ],
              'unreadCount': 1,
            }),
            200,
          )),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnreadNotificationIndicator(
            api: api,
            userId: 'customer-1',
            refreshToken: 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_unreadDot(), findsOneWidget);
    expect(find.bySemanticsLabel('Unread notifications'), findsOneWidget);
  });

  testWidgets('does not show a dot when notifications are all read',
      (tester) async {
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'data': [
                {'isRead': true},
              ],
            }),
            200,
          )),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnreadNotificationIndicator(
            api: api,
            userId: 'customer-1',
            refreshToken: 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_unreadDot(), findsNothing);
  });

  testWidgets('pauses unread refreshes while the app is backgrounded',
      (tester) async {
    var requests = 0;
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({'data': <dynamic>[], 'unreadCount': 0}),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnreadNotificationIndicator(
            api: api,
            userId: 'customer-1',
            refreshToken: 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pauses unread refreshes while the home tab is not visible',
      (tester) async {
    var requests = 0;
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({'data': <dynamic>[], 'unreadCount': 0}),
          200,
        );
      }),
    );

    Widget buildIndicator(bool visible) => MaterialApp(
          home: TickerMode(
            enabled: visible,
            child: Scaffold(
              body: UnreadNotificationIndicator(
                api: api,
                userId: 'customer-1',
                refreshToken: 0,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildIndicator(true));
    await tester.pumpAndSettle();
    expect(requests, 1);

    await tester.pumpWidget(buildIndicator(false));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    expect(requests, 1);

    await tester.pumpWidget(buildIndicator(true));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _unreadDot() => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color ==
              const Color(0xFFE12D39),
    );
