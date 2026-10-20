import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class UnreadNotificationIndicator extends StatefulWidget {
  final ApiService? api;
  final String? userId;
  final int refreshToken;
  final Widget child;

  const UnreadNotificationIndicator({
    super.key,
    required this.api,
    required this.userId,
    required this.refreshToken,
    required this.child,
  });

  @override
  State<UnreadNotificationIndicator> createState() =>
      _UnreadNotificationIndicatorState();
}

class _UnreadNotificationIndicatorState
    extends State<UnreadNotificationIndicator> {
  static const _refreshInterval = Duration(minutes: 1);
  Timer? _refreshTimer;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant UnreadNotificationIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _startRefreshTimer();
      unawaited(_refresh());
    }
  }

  void _startRefreshTimer() {
    if (widget.userId == null || widget.api == null) return;
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (widget.userId == null || widget.api == null) {
      if (mounted && _hasUnread) setState(() => _hasUnread = false);
      return;
    }
    try {
      final response =
          await widget.api!.get('/account/notifications');
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw const FormatException(
          'The store returned invalid notification data.',
        );
      }
      final unreadCount = response['unreadCount'];
      final hasUnread = unreadCount is int
          ? unreadCount > 0
          : (response['data'] as List)
              .whereType<Map<String, dynamic>>()
              .any((notification) => notification['isRead'] != true);
      if (mounted && hasUnread != _hasUnread) {
        setState(() => _hasUnread = hasUnread);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to refresh unread notification indicator: '
          '$error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _hasUnread ? 'Unread notifications' : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_hasUnread)
            Positioned(
              top: -1,
              right: -1,
              child: IgnorePointer(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE12D39),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
