import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/admin_models.dart';
import '../models/pos_models.dart';

class LocalPosDatabase {
  LocalPosDatabase._(this.path);

  static final Map<String, LocalPosDatabase> _instances = {};
  static const _databaseName = 'faststore_pos.sqlite';
  static final LocalPosDatabase instance = LocalPosDatabase._('');

  final String path;
  Future<Database>? _opening;
  List<PosProduct>? _catalogCache;
  Map<String, PosProduct>? _barcodeCache;

  static LocalPosDatabase atPath(String path) =>
      _instances.putIfAbsent(path, () => LocalPosDatabase._(path));

  static Future<LocalPosDatabase> defaultInstance() async {
    final directory = await getApplicationSupportDirectory();
    final databasePath = '${directory.path}${Platform.pathSeparator}'
        'offline_pos${Platform.pathSeparator}$_databaseName';
    return atPath(databasePath);
  }

  Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    await _database;
    await _loadCatalogCache();
  }

  Future<Database> get _database async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('The local POS database requires a desktop OS.');
    }
    final existing = _opening;
    if (existing != null) return existing;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    sqfliteFfiInit();
    final databaseDirectory = Directory(File(path).parent.path);
    await databaseDirectory.create(recursive: true);
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              sku TEXT NOT NULL,
              barcode TEXT,
              price REAL NOT NULL,
              unit_label TEXT NOT NULL,
              available INTEGER NOT NULL,
              image_url TEXT,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE wholesale_products (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              sku TEXT NOT NULL,
              barcode TEXT,
              price REAL NOT NULL,
              unit_label TEXT NOT NULL,
              available INTEGER NOT NULL,
              image_url TEXT,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE drinks_menu (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              sku TEXT NOT NULL DEFAULT '',
              barcode TEXT,
              price REAL NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT NOT NULL DEFAULT '',
              is_active INTEGER NOT NULL DEFAULT 1,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE bills (
              id TEXT PRIMARY KEY,
              invoice_number TEXT NOT NULL,
              created_at TEXT NOT NULL,
              total REAL NOT NULL,
              status TEXT NOT NULL,
              payment_status TEXT NOT NULL DEFAULT 'COMPLETED',
              sync_state TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE bill_items (
              id TEXT PRIMARY KEY,
              bill_id TEXT NOT NULL,
              product_id TEXT,
              name TEXT NOT NULL,
              sku TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              weight_grams INTEGER,
              unit_price REAL NOT NULL,
              amount REAL NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE
            )
          ''');
          await database.execute('''
            CREATE TABLE refunds (
              id TEXT PRIMARY KEY,
              bill_id TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE pending_cash (
              id TEXT PRIMARY KEY,
              bill_id TEXT NOT NULL DEFAULT '',
              customer_name TEXT NOT NULL DEFAULT '',
              amount REAL NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              raw_json TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE outbox (
              id TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE sync_metadata (
              table_name TEXT PRIMARY KEY,
              last_synced_at TEXT
            )
          ''');
          for (final table in [
            'products',
            'wholesale_products',
            'drinks_menu',
            'customers',
          ]) {
            await database.execute(
                'CREATE INDEX ${table}_name_idx ON $table(name COLLATE NOCASE)');
            await database.execute(
                'CREATE INDEX ${table}_updated_at_idx ON $table(updated_at)');
          }
          for (final table in ['products', 'wholesale_products']) {
            await database.execute(
                'CREATE INDEX ${table}_sku_idx ON $table(sku COLLATE NOCASE)');
            await database.execute(
                'CREATE INDEX ${table}_barcode_idx ON $table(barcode)');
          }
          await database.execute(
              'CREATE INDEX drinks_menu_sku_idx ON drinks_menu(sku COLLATE NOCASE)');
          await database.execute(
              'CREATE INDEX drinks_menu_barcode_idx ON drinks_menu(barcode)');
          await database.execute(
              'CREATE INDEX refunds_updated_at_idx ON refunds(updated_at)');
          await database.execute(
              'CREATE INDEX pending_cash_updated_at_idx ON pending_cash(updated_at)');
          await database
              .execute('CREATE INDEX customers_phone_idx ON customers(phone)');
          await database.execute(
              'CREATE INDEX bills_created_at_idx ON bills(created_at DESC)');
          await database.execute(
              'CREATE INDEX bills_updated_at_idx ON bills(updated_at)');
          await database.execute(
              'CREATE INDEX bills_sync_state_idx ON bills(sync_state)');
          await database.execute(
              'CREATE INDEX bills_payment_status_idx ON bills(payment_status)');
          await database.execute(
              'CREATE INDEX bill_items_bill_id_idx ON bill_items(bill_id)');
          await database.execute(
              'CREATE INDEX bill_items_updated_at_idx ON bill_items(updated_at)');
          await database.execute(
              'CREATE INDEX outbox_created_at_idx ON outbox(created_at)');
          await database
              .execute('CREATE INDEX refunds_bill_id_idx ON refunds(bill_id)');
          await database.execute('CREATE INDEX pending_cash_customer_name_idx '
              'ON pending_cash(customer_name COLLATE NOCASE)');
        },
      ),
    );
  }

  Future<void> replaceCatalog(List<PosProduct> products) async {
    final database = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.update('products', {'is_deleted': 1});
      await transaction.update('wholesale_products', {'is_deleted': 1});
      for (final product in products) {
        final wholesale = product.id.startsWith('wholesale-');
        await transaction.insert(
          wholesale ? 'wholesale_products' : 'products',
          {
            'id': product.id,
            'name': product.name,
            'sku': product.sku,
            'barcode': product.barcode,
            'price': product.price,
            'unit_label': product.unitLabel,
            'available': product.available,
            'image_url': product.imageUrl,
            'updated_at': now,
            'is_deleted': 0,
            'raw_json': jsonEncode(_productJson(product)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _catalogCache = List.unmodifiable(products);
    _barcodeCache = {
      for (final product in products)
        if (product.barcode?.trim().isNotEmpty == true)
          product.barcode!.trim().toLowerCase(): product,
    };
  }

  Future<List<PosProduct>> readCatalog() async {
    final cached = _catalogCache;
    if (cached != null) return cached;
    await _loadCatalogCache();
    return _catalogCache ?? const [];
  }

  Future<List<PosProduct>> searchCatalog(String query) async {
    final normalized = query.trim().toLowerCase();
    final products = await readCatalog();
    if (normalized.isEmpty) return products;
    final exactBarcode = _barcodeCache?[normalized];
    if (exactBarcode != null) return [exactBarcode];
    return products
        .where((product) =>
            product.name.toLowerCase().contains(normalized) ||
            product.sku.toLowerCase().contains(normalized) ||
            (product.barcode?.toLowerCase().contains(normalized) ?? false))
        .take(60)
        .toList(growable: false);
  }

  Future<void> _loadCatalogCache() async {
    final database = await _database;
    final rows = <Map<String, Object?>>[];
    rows.addAll(await database.query('products', where: 'is_deleted = 0'));
    rows.addAll(
        await database.query('wholesale_products', where: 'is_deleted = 0'));
    final products = rows
        .map((row) => PosProduct.fromJson(
            jsonDecode(row['raw_json']! as String) as Map<String, dynamic>))
        .toList(growable: false);
    _catalogCache = List.unmodifiable(products);
    _barcodeCache = {
      for (final product in products)
        if (product.barcode?.trim().isNotEmpty == true)
          product.barcode!.trim().toLowerCase(): product,
    };
  }

  Future<void> saveBill(Map<String, dynamic> record) async {
    final database = await _database;
    final id = record['id']?.toString() ?? record['invoiceNumber']?.toString();
    if (id == null || id.isEmpty) return;
    final rawItems = record['items'];
    final items = rawItems is List ? rawItems.whereType<Map>() : const <Map>[];
    final invoiceNumber = record['invoiceNumber']?.toString() ?? id;
    final now = DateTime.now().toUtc().toIso8601String();
    final normalizedRecord = _normalizeSaleJson(record, id, invoiceNumber);
    await database.transaction((transaction) async {
      await transaction.insert(
        'bills',
        {
          'id': id,
          'invoice_number': invoiceNumber,
          'created_at': record['date']?.toString() ??
              record['createdAt']?.toString() ??
              DateTime.now().toUtc().toIso8601String(),
          'total': _number(record['total']),
          'status': record['status']?.toString() ?? 'COMPLETED',
          'payment_status': record['paymentStatus']?.toString() ?? 'COMPLETED',
          'sync_state': record['syncState']?.toString() ?? 'local_only',
          'updated_at': now,
          'is_deleted': 0,
          'raw_json': jsonEncode(normalizedRecord),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final customerName = record['customerName']?.toString().trim() ?? '';
      final customerPhone = record['customerPhone']?.toString().trim() ?? '';
      if (customerName.isNotEmpty || customerPhone.isNotEmpty) {
        final customerId =
            'local-customer-${customerPhone.isNotEmpty ? customerPhone : customerName.toLowerCase()}';
        final customer = {
          'id': customerId,
          'profileId': '',
          'name': customerName.isEmpty ? 'Customer' : customerName,
          'email': '',
          'phone': customerPhone,
          'isActive': true,
          'createdAt': now,
          'orderCount': 1,
          'orderValue': _number(record['total']),
          'addresses': <Object>[],
          'recentOrders': <Object>[],
        };
        await transaction.insert(
          'customers',
          {
            'id': customerId,
            'name': customer['name'],
            'phone': customerPhone,
            'is_active': 1,
            'updated_at': now,
            'is_deleted': 0,
            'raw_json': jsonEncode(customer),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await transaction
          .delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
      for (var index = 0; index < items.length; index++) {
        final item = items.elementAt(index);
        final itemId = item['id']?.toString() ?? '$id-$index';
        await transaction.insert(
            'bill_items',
            {
              'id': itemId,
              'bill_id': id,
              'product_id': item['productId']?.toString(),
              'name': item['name']?.toString() ??
                  item['productName']?.toString() ??
                  '',
              'sku': item['sku']?.toString() ?? '',
              'quantity': _number(item['quantity']).toInt(),
              'weight_grams': item['weightGrams'] == null
                  ? null
                  : _number(item['weightGrams']).toInt(),
              'unit_price': _number(item['unitPrice'] ?? item['price']),
              'amount': _number(item['amount'] ?? item['lineTotal']),
              'updated_at': now,
              'is_deleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> updateBillSyncState(String id, String state) async {
    final database = await _database;
    final rows = await database.query('bills',
        columns: ['raw_json'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final record =
        jsonDecode(rows.first['raw_json']! as String) as Map<String, dynamic>;
    record['syncState'] = state;
    await database.update(
      'bills',
      {
        'sync_state': state,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'raw_json': jsonEncode(record),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> readBill(String id) async {
    final database = await _database;
    final rows = await database.query('bills',
        columns: ['raw_json'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['raw_json']! as String)
        as Map<String, dynamic>;
  }

  Future<PosSalesPage> readBillsPage({int page = 1, int pageSize = 50}) async {
    final database = await _database;
    const where = 'is_deleted = 0';
    final countRows = await database
        .rawQuery('SELECT COUNT(*) AS count FROM bills WHERE $where');
    final total = countRows.first['count'] as int? ?? 0;
    final rows = await database.query(
      'bills',
      columns: ['raw_json'],
      where: where,
      orderBy: 'created_at DESC, id DESC',
      limit: pageSize,
      offset: (page - 1) * pageSize,
    );
    final sales = <PosSale>[];
    for (final row in rows) {
      try {
        sales.add(PosSale.fromJson(
            jsonDecode(row['raw_json']! as String) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed cache row; file recovery remains a separate path.
      }
    }
    return PosSalesPage(
        sales: sales, page: page, pageSize: pageSize, total: total);
  }

  Future<PosSalesPage> readPendingPayments(
      {int page = 1, int pageSize = 50}) async {
    final database = await _database;
    const where =
        'is_deleted = 0 AND payment_status = ? AND status NOT IN (?, ?)';
    const arguments = ['PENDING', 'CANCELLED', 'CHECKOUT'];
    final countRows = await database.rawQuery(
        'SELECT COUNT(*) AS count FROM bills WHERE $where', arguments);
    final total = countRows.first['count'] as int? ?? 0;
    final rows = await database.query(
      'bills',
      columns: ['raw_json'],
      where: where,
      whereArgs: arguments,
      orderBy: 'created_at ASC, id ASC',
      limit: pageSize,
      offset: (page - 1) * pageSize,
    );
    final sales = <PosSale>[];
    for (final row in rows) {
      try {
        sales.add(PosSale.fromJson(
            jsonDecode(row['raw_json']! as String) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed cache row.
      }
    }
    return PosSalesPage(
        sales: sales, page: page, pageSize: pageSize, total: total);
  }

  Future<List<PosRefund>> readRefunds() async {
    final database = await _database;
    final rows = await database.query('refunds',
        columns: ['raw_json'],
        where: 'is_deleted = 0',
        orderBy: 'created_at DESC');
    return rows
        .map((row) => PosRefund.fromJson(
            jsonDecode(row['raw_json']! as String) as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> pendingOutbox() async {
    final database = await _database;
    return database.query('outbox', orderBy: 'created_at ASC');
  }

  Future<void> completeOutbox(String id) async {
    final database = await _database;
    await database.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> recordOutboxFailure(String id, String message) async {
    final database = await _database;
    await database.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [message, id],
    );
  }

  Future<List<AdminCustomer>> readCustomers() async {
    final database = await _database;
    final rows = await database.query('customers',
        columns: ['raw_json'],
        where: 'is_active = 1 AND is_deleted = 0',
        orderBy: 'name COLLATE NOCASE');
    return rows
        .map((row) => AdminCustomer.fromJson(
            jsonDecode(row['raw_json']! as String) as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveCustomers(List<AdminCustomer> customers) async {
    final database = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final customer in customers) {
        final raw = {
          'id': customer.id,
          'profileId': customer.profileId,
          'name': customer.name,
          'email': customer.email,
          'phone': customer.phone,
          'isActive': customer.isActive,
          'createdAt': customer.createdAt,
          'orderCount': customer.orderCount,
          'orderValue': customer.orderValue,
          'addresses': customer.addresses,
          'recentOrders': customer.recentOrders,
        };
        await transaction.insert(
          'customers',
          {
            'id': customer.id,
            'name': customer.name,
            'phone': customer.phone,
            'is_active': customer.isActive ? 1 : 0,
            'updated_at': now,
            'is_deleted': 0,
            'raw_json': jsonEncode(raw),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<String>> tableNames() async {
    final database = await _database;
    final rows = await database.query('sqlite_master',
        columns: ['name'], where: "type = 'table'", orderBy: 'name');
    return rows.map((row) => row['name']! as String).toList(growable: false);
  }

  Future<void> enqueue({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final database = await _database;
    await database.insert(
        'outbox',
        {
          'id': id,
          'entity_type': entityType,
          'entity_id': entityId,
          'operation': operation,
          'payload': jsonEncode(payload),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> setLastSyncedAt(String tableName, DateTime value) async {
    final database = await _database;
    await database.insert(
      'sync_metadata',
      {
        'table_name': tableName,
        'last_synced_at': value.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> lastSyncedAt(String tableName) async {
    final database = await _database;
    final rows = await database.query('sync_metadata',
        columns: ['last_synced_at'],
        where: 'table_name = ?',
        whereArgs: [tableName],
        limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['last_synced_at']?.toString() ?? '');
  }

  Future<void> clearSyncMetadata(Iterable<String> tables) async {
    final database = await _database;
    await database.transaction((transaction) async {
      for (final table in tables) {
        await transaction.delete('sync_metadata',
            where: 'table_name = ?', whereArgs: [table]);
      }
    });
  }

  Future<void> applySyncBatch(Map<String, dynamic> batch) async {
    final database = await _database;
    final cutoff = DateTime.tryParse(batch['cutoff']?.toString() ?? '') ??
        DateTime.now().toUtc();
    List<Map<String, dynamic>> rows(String key) =>
        (batch[key] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);

    await database.transaction((transaction) async {
      for (final row in rows('products')) {
        final product = PosProduct.fromJson(row);
        final isDeleted = row['isActive'] == false;
        await transaction.insert(
          'products',
          {
            'id': product.id,
            'name': product.name,
            'sku': product.sku,
            'barcode': product.barcode,
            'price': product.price,
            'unit_label': product.unitLabel,
            'available': product.available,
            'image_url': product.imageUrl,
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': isDeleted ? 1 : 0,
            'raw_json': jsonEncode(_productJson(product)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in rows('wholesaleProducts')) {
        final product = PosProduct(
          id: 'wholesale-${row['id']}',
          name: row['name']?.toString() ?? '',
          sku: row['sku']?.toString() ?? '',
          barcode: null,
          price: _number(row['price']).toDouble(),
          unitLabel: row['unitLabel']?.toString() ?? 'unit',
          available: _number(row['stock']).toInt(),
          imageUrl: row['imageUrl']?.toString(),
        );
        await transaction.insert(
          'wholesale_products',
          {
            'id': product.id,
            'name': product.name,
            'sku': product.sku,
            'barcode': null,
            'price': product.price,
            'unit_label': product.unitLabel,
            'available': product.available,
            'image_url': product.imageUrl,
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': row['isActive'] == false ? 1 : 0,
            'raw_json': jsonEncode(_productJson(product)),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in rows('drinks')) {
        await transaction.insert(
          'drinks_menu',
          {
            'id': row['id'],
            'name': row['name']?.toString() ?? '',
            'sku': row['sku']?.toString() ?? '',
            'barcode': row['barcode']?.toString(),
            'price': _number(row['price']),
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': row['isActive'] == false ? 1 : 0,
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in rows('customers')) {
        await transaction.insert(
          'customers',
          {
            'id': row['id'],
            'name': row['name']?.toString() ?? '',
            'phone': row['phone']?.toString() ?? '',
            'is_active': row['isActive'] == false ? 0 : 1,
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': row['isActive'] == false ? 1 : 0,
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in rows('bills')) {
        final billId = row['id']?.toString();
        if (billId == null || billId.isEmpty) continue;
        final bill = {...row, 'syncState': 'synced'};
        await transaction.insert(
          'bills',
          {
            'id': billId,
            'invoice_number': row['invoiceNumber']?.toString() ??
                row['receiptNumber']?.toString() ??
                billId,
            'created_at':
                row['createdAt']?.toString() ?? cutoff.toIso8601String(),
            'total': _number(row['total']),
            'status': row['status']?.toString() ?? 'COMPLETED',
            'payment_status': row['paymentStatus']?.toString() ?? 'COMPLETED',
            'sync_state': 'synced',
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': 0,
            'raw_json': jsonEncode(bill),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await transaction
            .delete('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
        for (final item
            in (row['items'] as List? ?? const []).whereType<Map>()) {
          final itemId = item['id']?.toString() ??
              '$billId-${item['productId'] ?? item['sku'] ?? ''}';
          await transaction.insert(
            'bill_items',
            {
              'id': itemId,
              'bill_id': billId,
              'product_id': item['productId']?.toString(),
              'name': item['productName']?.toString() ?? '',
              'sku': item['sku']?.toString() ?? '',
              'quantity': _number(item['quantity']).toInt(),
              'weight_grams': item['weightGrams'] == null
                  ? null
                  : _number(item['weightGrams']).toInt(),
              'unit_price': _number(item['unitPrice']),
              'amount': _number(item['lineTotal']),
              'updated_at':
                  row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
              'is_deleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      for (final row in rows('refunds')) {
        await transaction.insert(
          'refunds',
          {
            'id': row['id'],
            'bill_id': row['saleId']?.toString() ?? '',
            'created_at':
                row['requestedAt']?.toString() ?? cutoff.toIso8601String(),
            'amount': _number(row['amount']),
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': row['isDeleted'] == true ? 1 : 0,
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in rows('pendingCash')) {
        await transaction.insert(
          'pending_cash',
          {
            'id': row['id'],
            'bill_id': row['id'],
            'customer_name': row['customerName']?.toString() ?? '',
            'amount': _number(row['amount']),
            'updated_at':
                row['updatedAt']?.toString() ?? cutoff.toIso8601String(),
            'is_deleted': row['isDeleted'] == true ? 1 : 0,
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final table in [
        'products',
        'wholesale_products',
        'drinks_menu',
        'customers',
        'bills',
        'refunds',
        'pending_cash',
      ]) {
        await transaction.insert(
          'sync_metadata',
          {
            'table_name': table,
            'last_synced_at': cutoff.toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _catalogCache = null;
    _barcodeCache = null;
    await _loadCatalogCache();
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final database = await opening;
    await database.close();
    _opening = null;
    _catalogCache = null;
    _barcodeCache = null;
  }

  static Map<String, dynamic> _productJson(PosProduct product) => {
        'id': product.id,
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'price': product.price,
        'unitLabel': product.unitLabel,
        'available': product.available,
        'imageUrl': product.imageUrl,
      };

  static Map<String, dynamic> _normalizeSaleJson(
    Map<String, dynamic> record,
    String id,
    String invoiceNumber,
  ) {
    final rawItems = record['items'];
    return {
      ...record,
      'id': id,
      'receiptNumber': record['receiptNumber']?.toString() ?? invoiceNumber,
      'invoiceNumber': invoiceNumber,
      'createdAt': record['createdAt']?.toString() ??
          record['date']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'paymentCollections': record['paymentCollections'] ?? const [],
      'items': rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => {
                    ...Map<String, dynamic>.from(item),
                    'productName': item['productName']?.toString() ??
                        item['name']?.toString() ??
                        '',
                    'lineTotal': item['lineTotal'] ?? item['amount'] ?? 0,
                  })
              .toList(growable: false)
          : const <Map<String, dynamic>>[],
    };
  }

  static num _number(Object? value) => value is num ? value : 0;
}
