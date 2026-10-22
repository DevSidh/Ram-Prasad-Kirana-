import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'services/api_service.dart';
import 'services/product_share_link.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/store_availability_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/product/shared_product_screen.dart';
import 'widgets/store_animation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConstants.validateApiConfiguration();
  ErrorWidget.builder = (_) => const StorePageError();

  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiService: apiService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (_) => ProductProvider(apiService: apiService),
          update: (_, auth, products) {
            final provider =
                products ?? ProductProvider(apiService: apiService);
            provider.setAuthenticatedUser(auth.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(apiService: apiService),
          update: (_, auth, cart) {
            final provider = cart ?? CartProvider(apiService: apiService);
            provider.setAuthenticatedUser(auth.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(apiService: apiService),
        ),
        ChangeNotifierProvider<StoreAvailabilityProvider>(
          create: (_) => StoreAvailabilityProvider(apiService: apiService),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AppLanguageProvider>(
          create: (_) => AppLanguageProvider(),
        ),
      ],
      child: const RamPrasadGeneralStoreApp(),
    ),
  );
}

class RamPrasadGeneralStoreApp extends StatelessWidget {
  const RamPrasadGeneralStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final languageCode = context.watch<AppLanguageProvider>().languageCode;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            View.of(context).platformDispatcher.platformBrightness ==
                Brightness.dark);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: Locale(languageCode),
      supportedLocales: const [Locale('en'), Locale('ne')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const _StoreScrollBehavior(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: AppConstants.backgroundFor(isDark),
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        final productId = sharedProductIdFromRoute(settings.name);
        if (productId == null) return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SharedProductScreen(productId: productId),
        );
      },
    );
  }
}

class _StoreScrollBehavior extends MaterialScrollBehavior {
  const _StoreScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (getPlatform(context) == TargetPlatform.android) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return super.getScrollPhysics(context);
  }
}
