import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/user.dart';
import 'package:freshharvest_grocery/navigation/app_shell_route.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/screens/admin/admin_shell.dart';
import 'package:freshharvest_grocery/screens/delivery/delivery_shell.dart';

void main() {
  test('ADMIN users enter the separate admin shell', () {
    final shell = appShellForUser(
      User(
          id: '1',
          email: 'admin@example.test',
          fullName: 'Admin',
          role: 'ADMIN'),
    );

    expect(shell, isA<StaffAppearanceBoundary>());
    expect((shell as StaffAppearanceBoundary).child, isA<AdminShell>());
  });

  test('non-admin users remain in the customer shell', () {
    final shell = appShellForUser(
      User(
        id: '2',
        email: 'customer@example.test',
        fullName: 'Customer',
        role: 'CUSTOMER',
      ),
    );

    expect(shell, isA<MainBottomNav>());
  });

  test('delivery staff enter a separate delivery panel', () {
    final shell = appShellForUser(
      User(
        id: '3',
        email: 'rider@example.test',
        fullName: 'Rider',
        role: 'DELIVERY_PERSON',
      ),
    );

    expect(shell, isA<StaffAppearanceBoundary>());
    expect((shell as StaffAppearanceBoundary).child, isA<DeliveryShell>());
  });
}
