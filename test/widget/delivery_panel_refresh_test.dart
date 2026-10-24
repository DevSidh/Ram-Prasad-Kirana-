import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/screens/delivery/delivery_panel_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _DeliveryApi extends ApiService {
  int profileCalls = 0;
  int assignmentCalls = 0;
  final _profileRefresh = Completer<dynamic>();
  final _assignmentRefresh = Completer<dynamic>();

  static const _profile = {
    'id': 'rider-1',
    'name': 'Ram',
    'email': 'ram@example.test',
    'phone': '9800000000',
    'isAvailable': true,
  };

  static const _assignments = {
    'assignments': <dynamic>[],
    'summary': {
      'assigned': 0,
      'inProgress': 0,
      'deliveredToday': 0,
      'cashCollectedToday': 0,
    },
  };

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/delivery/profile') {
      profileCalls++;
      return profileCalls == 1 ? _profile : _profileRefresh.future;
    }
    if (endpoint == '/delivery/assignments') {
      assignmentCalls++;
      return assignmentCalls == 1 ? _assignments : _assignmentRefresh.future;
    }
    throw StateError('Unexpected delivery API GET: $endpoint');
  }

  void completeRefresh() {
    if (!_profileRefresh.isCompleted) _profileRefresh.complete(_profile);
    if (!_assignmentRefresh.isCompleted) {
      _assignmentRefresh.complete(_assignments);
    }
  }
}

void main() {
  testWidgets('periodic delivery refresh does not overlap requests',
      (tester) async {
    final api = _DeliveryApi();
    addTearDown(api.completeRefresh);

    await tester.pumpWidget(
      MaterialApp(home: DeliveryPanelScreen(api: api)),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(api.profileCalls, 2);
    expect(api.assignmentCalls, 2);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(api.profileCalls, 2);
    expect(api.assignmentCalls, 2);

    api.completeRefresh();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
