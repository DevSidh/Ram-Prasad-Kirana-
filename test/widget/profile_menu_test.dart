import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/screens/auth/login_screen.dart';
import 'package:freshharvest_grocery/screens/profile/profile_screen.dart';
import 'package:freshharvest_grocery/screens/profile/profile_options_screens.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/secure_login_service.dart';

class _DeletionApi extends ApiService {
  String? deletedAccountEndpoint;

  _DeletionApi() : super(baseUrl: 'https://store.example/api/v1');

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    deletedAccountEndpoint = endpoint;
    return {
      'message':
          'Your account was deleted and historical orders were anonymized.'
    };
  }
}

class _TestSecureLoginService extends SecureLoginService {
  bool credentialsCleared = false;

  @override
  Future<void> clear() async {
    credentialsCleared = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profile menu groups preferences and help for customers',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: api),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: api),
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final profileScrollable = find.descendant(
      of: find.byKey(const ValueKey('profile-menu-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Preferences & payments'),
      160,
      scrollable: profileScrollable,
    );
    expect(find.text('Preferences & payments'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Help & account'),
      160,
      scrollable: profileScrollable,
    );
    expect(find.text('Help & account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile background remains transparent behind the shared nav',
      (tester) async {
    final api = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: api),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: api),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    final profileScaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(profileScaffold.backgroundColor, Colors.transparent);
    expect((profileScaffold.body! as SafeArea).bottom, isFalse);
  });

  testWidgets('guest account actions sign in before opening private screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: api),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: api),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final profileScrollable = find.descendant(
      of: find.byKey(const ValueKey('profile-menu-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Help & account'),
      160,
      scrollable: profileScrollable,
    );
    expect(find.text('Log Out'), findsNothing);

    await tester.drag(profileScrollable, const Offset(0, 1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Addresses'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).returnToCaller,
      isTrue,
    );
  });

  testWidgets('payment methods only advertises the enabled COD option',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaymentPreferenceScreen()),
    );

    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.text('Khalti wallet'), findsNothing);
    expect(find.text('eSewa wallet'), findsNothing);
    expect(
      find.textContaining('only payment method'),
      findsOneWidget,
    );
  });

  testWidgets('customer can confirm account deletion from the profile menu',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'auth_token': 'session-token',
      'user_data': '''
        {"id":"customer-1","email":"customer@example.com",
         "fullName":"Customer","phone":"9800000000","role":"CUSTOMER"}
      ''',
    });
    final api = _DeletionApi();
    final auth = AuthProvider(apiService: api);
    final secureLogin = _TestSecureLoginService();
    addTearDown(auth.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: api),
          ),
        ],
        child: MaterialApp(
          home: ProfileScreen(secureLoginService: secureLogin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final profileScrollable = find.descendant(
      of: find.byKey(const ValueKey('profile-menu-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(profileScrollable, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete account').first);
    await tester.tap(find.text('Delete account').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'correct-password');
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();

    expect(api.deletedAccountEndpoint, '/account/delete-account');
    expect(secureLogin.credentialsCleared, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(tester.takeException(), isNull);
  });
}
