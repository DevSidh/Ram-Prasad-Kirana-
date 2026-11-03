import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/update/app_update_screen.dart';
import '../services/app_update_service.dart';

class AppUpdateStartup extends StatefulWidget {
  const AppUpdateStartup({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AppUpdateStartup> createState() => _AppUpdateStartupState();
}

class _AppUpdateStartupState extends State<AppUpdateStartup>
    with WidgetsBindingObserver {
  static bool _updatePresentedThisSession = false;
  bool _checking = false;
  bool _hasEnteredBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSilently());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _hasEnteredBackground = true;
    } else if (state == AppLifecycleState.resumed && _hasEnteredBackground) {
      _hasEnteredBackground = false;
      _checkSilently();
    }
  }

  Future<void> _checkSilently() async {
    if (kIsWeb ||
        !Platform.isAndroid ||
        _checking ||
        _updatePresentedThisSession) {
      return;
    }
    _checking = true;
    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!mounted || !result.updateAvailable) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      _updatePresentedThisSession = true;
      unawaited(navigator.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => AppUpdateScreen(initialCheck: result),
        ),
      ));
    } catch (_) {
      // GitHub availability must never block normal app startup.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
