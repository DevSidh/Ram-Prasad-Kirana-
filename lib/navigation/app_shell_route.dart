import 'package:flutter/widgets.dart';

import '../models/user.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/delivery/delivery_shell.dart';
import 'main_bottom_nav.dart';

Widget appShellForUser(User? user) {
  if (user?.role.toUpperCase() == 'ADMIN') {
    return const AdminShell();
  }
  if (user?.role.toUpperCase() == 'DELIVERY_PERSON') {
    return const DeliveryShell();
  }
  return const MainBottomNav();
}
