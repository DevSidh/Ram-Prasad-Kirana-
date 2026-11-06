// Isolated native preview. Every API call and catalog write stays in memory.
// Run using the "Preview isolated admin audit" VS Code task.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/providers/language_provider.dart';
import 'package:freshharvest_grocery/screens/admin/admin_products_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_wholesale_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_skus_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart';
import 'package:freshharvest_grocery/theme/app_colors.dart';
import 'package:freshharvest_grocery/widgets/billing_language_switch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A test-only executable must not read the cashier's saved session/preferences.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await BillingStrings.load();
  runApp(ChangeNotifierProvider(
      create: (_) => AppLanguageProvider(), child: const _Preview()));
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final api = _PreviewApi();
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    AppColors.windowsAdminDarkTheme = dark;
    return MaterialApp(
        theme: AppTheme.data,
        home: DefaultTabController(
            length: 3,
            child: Scaffold(
              backgroundColor: AppColors.pageStart,
              appBar: AppBar(
                  title: const Text('FastStore — ISOLATED TEST DATA'),
                  actions: [
                    IconButton(
                        tooltip: 'Toggle test theme',
                        onPressed: () => setState(() => dark = !dark),
                        icon: const Icon(Icons.contrast)),
                  ],
                  bottom: const TabBar(tabs: [
                    Tab(text: 'Products'),
                    Tab(text: 'Wholesale'),
                    Tab(text: 'SKU editor')
                  ])),
              body: Column(children: [
                const BillingLanguageSwitch(),
                Expanded(
                    child: TabBarView(children: [
                  AdminProductsScreen(
                      api: api, offlineStore: const _MemoryStore()),
                  AdminWholesaleScreen(
                      api: api, offlineStore: const _MemoryStore()),
                  AdminSkusScreen(api: api),
                ]))
              ]),
            )));
  }
}

class _MemoryStore extends OfflinePosStore {
  const _MemoryStore();
  @override
  Future<void> mergeCatalog(List<PosProduct> products) async {}
  @override
  Future<List<Map<String, dynamic>>> readPendingProducts() async => [];
  @override
  Future<List<Map<String, dynamic>>> readCategories() async => [];
  @override
  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {}
  @override
  Future<List<PosProduct>> projectLocalStock(List<PosProduct> products,
          {bool freshStock = false}) async =>
      products;
}

class _PreviewApi extends ApiService {
  @override
  Future<Uint8List> getBytes(String endpoint) async => _blocked();
  @override
  Future<dynamic> postFile(String endpoint,
          {required String fieldName,
          required Uint8List bytes,
          required String fileName,
          Map<String, String> fields = const {},
          String method = 'POST'}) async =>
      _blocked();
  @override
  Future<dynamic> get(String endpoint,
          {Map<String, String>? queryParams}) async =>
      {
        'products': [
          {
            'id': 'test-rice',
            'name': 'Test Rice / परीक्षण चामल',
            'sku': 'TEST-RICE',
            'slug': 'test-rice',
            'categoryId': 'test-category',
            'category': {'id': 'test-category', 'name': 'Test pantry'},
            'price': 235,
            'stock': 12,
            'unitLabel': '1 pc',
            'isActive': true
          },
        ],
        'categories': [
          {
            'id': 'test-category',
            'name': 'Test pantry',
            'slug': 'test-pantry',
            'isActive': true
          }
        ],
        'wholesaleItems': [
          {
            'id': 'test-sack',
            'name': 'Test Rice Sack',
            'sku': 'TEST-SACK',
            'categoryId': 'test-category',
            'price': 2500,
            'stock': 5,
            'unitLabel': '25 kg',
            'minimumQuantity': 1,
            'isActive': true
          }
        ],
        'pagination': {'page': 1, 'pageSize': 100, 'total': 1},
      };
  Never _blocked() => throw const ApiResponseException(
      'This isolated preview blocks mutations.');
  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async =>
      _blocked();
  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async =>
      _blocked();
  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async =>
      _blocked();
  @override
  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async =>
      _blocked();
}
