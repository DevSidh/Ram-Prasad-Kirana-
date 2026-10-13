import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/delivery/delivery_shell.dart';
import 'main_bottom_nav.dart';

Widget appShellForUser(User? user) {
  if (user?.role.toUpperCase() == 'ADMIN') {
    return const StaffAppearanceBoundary(child: AdminShell());
  }
  if (user?.role.toUpperCase() == 'DELIVERY_PERSON') {
    return const StaffAppearanceBoundary(child: DeliveryShell());
  }
  AppConstants.setThemeOverride(null);
  return const MainBottomNav();
}

class StaffAppearanceBoundary extends StatefulWidget {
  final Widget child;

  const StaffAppearanceBoundary({super.key, required this.child});

  @override
  State<StaffAppearanceBoundary> createState() =>
      _StaffAppearanceBoundaryState();
}

class _StaffAppearanceBoundaryState extends State<StaffAppearanceBoundary> {
  @override
  void initState() {
    super.initState();
    AppConstants.setThemeOverride(false);
  }

  @override
  void dispose() {
    AppConstants.setThemeOverride(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFE7EFE8),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: widget.child,
      ),
    );
  }
}
