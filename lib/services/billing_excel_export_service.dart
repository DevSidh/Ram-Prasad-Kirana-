import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/admin_models.dart';
import '../models/pos_models.dart';
import '../core/nepal_phone.dart';
import 'local_billing_store.dart';
import 'ordered_work_queue.dart';
import 'billing_workbook.dart';

/// Writes Excel-compatible CSV ledgers beside locally stored Windows bills.
class BillingExcelExportService {
  BillingExcelExportService._();
  static final _workbooks = OrderedWorkQueue();
  static final _dirtyWrites = OrderedWorkQueue();

  static String? baseDirectoryOverride;
  static String get _baseDirectory =>
      baseDirectoryOverride ?? 'C:/Ramprasad store/bills';

  static Future<String> _customerDirectory() async {
    if (baseDirectoryOverride != null || Platform.isWindows) {
      return _baseDirectory;
    }
    final support = await getApplicationSupportDirectory();
    return '${support.path}/billing';
  }

  static Future<String> writePendingCash(
    List<PosSale> sales, {
    List<Map<String, dynamic>> localPendingRecords = const [],
    bool localOnly = false,
  }) async {
    final root = await _customerDirectory();
    final directory = Directory('$root/pending cash');
    await directory.create(recursive: true);
    final file = File(
        '${directory.path}/${localOnly ? 'pending_cash_local.csv' : 'pending_cash.csv'}');
    final rows = <List<String>>[
      [
        'Invoice number',
        'Date',
        'Customer name',
        'Customer phone',
        'Bill total',
        'Paid',
        'Cash pending',
        'Payment status',
        'Payment history',
      ],
      for (final sale in sales)
        [
          _cell(sale.invoiceNumber ?? sale.receiptNumber, protectFormula: true),
          _cell(sale.createdAt.toLocal().toString()),
          _cell(sale.customerName ?? '', protectFormula: true),
          _cell(sale.customerPhone ?? '', protectFormula: true),
          _cell(sale.total.toStringAsFixed(2)),
          _cell(_paid(sale).toStringAsFixed(2)),
          _cell(_due(sale).toStringAsFixed(2)),
          _cell(sale.paymentStatus),
          _cell(
            sale.paymentCollections
                .map((payment) =>
                    '${payment.createdAt.toLocal().toString()} ${payment.method} ${payment.amount.toStringAsFixed(2)} ${payment.note ?? ''}')
                .join(' | '),
          ),
        ],
      for (final record in localPendingRecords)
        [
          _cell(record['invoiceNumber']?.toString() ?? '',
              protectFormula: true),
          _cell(record['date']?.toString() ?? ''),
          _cell(record['customerName']?.toString() ?? '', protectFormula: true),
          _cell(record['customerPhone']?.toString() ?? '',
              protectFormula: true),
          _cell(_number(record['total']).toStringAsFixed(2)),
          _cell(_number(record['paid']).toStringAsFixed(2)),
          _cell(_number(record['due']).toStringAsFixed(2)),
          _cell(record['paymentStatus']?.toString() ?? 'PENDING'),
          _cell('Offline bill'),
        ],
    ];
    await LocalBillingStore(rootPath: root).withLock(() async {
      final source = await file.exists() ? await file.readAsString() : '';
      final incoming = _parseCsv(_encode(rows));
      final existing = _parseCsv(source);
      if (existing.isEmpty) {
        await _replaceText(file, _encode(rows));
        return;
      }
      final header = existing.first;
      final invoiceColumn = header.indexOf('Invoice number');
      if (invoiceColumn < 0) {
        throw const FormatException(
            'Keep the Invoice number header in the pending cash CSV. No rows were changed.');
      }
      // Preserve the user's row order, added columns and unrelated manual rows.
      final positions = <String, int>{};
      for (var i = 1; i < existing.length; i++) {
        if (existing[i].length > invoiceColumn &&
            existing[i][invoiceColumn].trim().isNotEmpty) {
          positions.putIfAbsent(existing[i][invoiceColumn], () => i);
        }
      }
      for (final next in incoming.skip(1)) {
        final key = next.first;
        final position = positions[key];
        final row = position == null
            ? List<String>.filled(header.length, '')
            : existing[position];
        while (row.length < header.length) {
          row.add('');
        }
        for (var column = 0; column < incoming.first.length; column++) {
          final target = header.indexOf(incoming.first[column]);
          if (target >= 0) row[target] = next[column];
        }
        if (position == null) {
          positions[key] = existing.length;
          existing.add(row);
        }
      }
      if (await file.readAsString() != source) {
        throw StateError(
            'The pending cash CSV changed in Excel. Save and close it, then retry.');
      }
      await _replaceText(
          file,
          _encode(existing
              .map((row) => row.map((value) => _cell(value)).toList())
              .toList()));
    });
    await _markWorkbookDirty(root);
    return file.path;
  }

  static Future<String> recordBillCustomer(PosSale sale) async {
    final root = await _customerDirectory();
    final directory = Directory('$root/bill customer');
    await directory.create(recursive: true);
    final file = File('${directory.path}/bill_customers.csv');
    final exists = await file.exists();
    if (exists &&
        _parseCsv(await file.readAsString()).skip(1).any((row) =>
            row.isNotEmpty &&
            row.first == (sale.invoiceNumber ?? sale.receiptNumber))) {
      await _upsertSavedCustomer(sale);
      return file.path;
    }
    final rows = <List<String>>[
      if (!exists || await file.length() == 0)
        [
          'Invoice number',
          'Date',
          'Customer name',
          'Customer phone',
          'Payment method',
          'Payment status',
          'Bill total',
          'Paid',
          'Balance due',
        ],
      [
        _cell(sale.invoiceNumber ?? sale.receiptNumber, protectFormula: true),
        _cell(sale.createdAt.toLocal().toString()),
        _cell(sale.customerName ?? '', protectFormula: true),
        _cell(sale.customerPhone ?? '', protectFormula: true),
        _cell(sale.paymentMethod),
        _cell(sale.paymentStatus),
        _cell(sale.total.toStringAsFixed(2)),
        _cell(_paid(sale).toStringAsFixed(2)),
        _cell(_due(sale).toStringAsFixed(2)),
      ],
    ];
    await file.writeAsString(
      _encode(rows, includeBom: !exists || await file.length() == 0),
      mode: FileMode.append,
      flush: true,
    );
    await _upsertSavedCustomer(sale);
    return file.path;
  }

  /// Returns customer details previously saved with billing records on this PC.
  static Future<List<AdminCustomer>> readSavedCustomers() async {
    final root = await _customerDirectory();
    final file = File('$root/bill customer/customers.json');
    List<Map<String, dynamic>> records = [];
    try {
      try {
        if (await file.exists()) {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is List) {
            records = decoded.whereType<Map<String, dynamic>>().toList();
          }
        }
      } on FormatException {
        /* Recover names from the CSV export below. */
      } on FileSystemException {/* The CSV can still be readable. */}
      try {
        if (Platform.isWindows || baseDirectoryOverride != null) {
          records.addAll(await _customersFromLegacyCsv());
        }
      } on FormatException {
        /* Keep valid JSON customers. */
      } on FileSystemException {/* Keep valid JSON customers. */}
      return records
          .map((record) => AdminCustomer(
                id: record['id']?.toString() ?? '',
                profileId: record['id']?.toString() ?? '',
                name: record['name']?.toString() ?? '',
                email: record['email']?.toString() ?? '',
                phone: record['phone']?.toString() ?? '',
                isActive: record['isActive'] is bool
                    ? record['isActive'] as bool
                    : true,
                createdAt: record['createdAt']?.toString(),
                orderCount: record['orderCount'] is num
                    ? (record['orderCount'] as num).toInt()
                    : int.tryParse('${record['orderCount']}') ?? 0,
                orderValue: _number(record['orderValue']),
                addresses: record['addresses'] is List
                    ? (record['addresses'] as List)
                        .whereType<Map<String, dynamic>>()
                        .toList()
                    : const [],
                recentOrders: const [],
              ))
          .where((customer) =>
              customer.name.trim().isNotEmpty ||
              customer.phone.trim().isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on FileSystemException {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> _customersFromLegacyCsv() async {
    final file = File('$_baseDirectory/bill customer/bill_customers.csv');
    if (!await file.exists()) return [];
    final rows = _parseCsv(await file.readAsString());
    if (rows.length < 2) return [];
    final customers = <String, Map<String, dynamic>>{};
    for (final row in rows.skip(1)) {
      if (row.length < 4) continue;
      final name = row[2].trim();
      final phone = row[3].trim();
      if (name.isEmpty && phone.isEmpty) continue;
      final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
      final key =
          normalizedPhone.isNotEmpty ? normalizedPhone : name.toLowerCase();
      final customer = customers.putIfAbsent(
          key,
          () => {
                'id': 'local-customer-$key',
                'name': name,
                'phone': phone,
                'email': '',
                'isActive': true,
                'createdAt': row.length > 1 ? row[1] : '',
                'orderCount': 0,
                'orderValue': 0.0,
              });
      customer['orderCount'] = (customer['orderCount'] as int) + 1;
      customer['orderValue'] = _number(customer['orderValue']) +
          (row.length > 6 ? _number(row[6]) : 0);
    }
    return customers.values.toList(growable: false);
  }

  static List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (character == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
      } else if ((character == '\r' || character == '\n') && !quoted) {
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
    }
    if (rows.isNotEmpty && rows.first.isNotEmpty) {
      rows.first[0] = rows.first[0].replaceFirst('\uFEFF', '');
    }
    return rows;
  }

  static Future<void> _upsertSavedCustomer(PosSale sale) =>
      _customerDirectory().then((root) => LocalBillingStore(rootPath: root)
          .withLock(() => _upsertSavedCustomerUnlocked(sale)));

  static Future<void> _upsertSavedCustomerUnlocked(PosSale sale) async {
    final name = sale.customerName?.trim() ?? '';
    final phone = sale.customerPhone?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) return;
    final root = await _customerDirectory();
    final directory = Directory('$root/bill customer');
    await directory.create(recursive: true);
    final file = File('${directory.path}/customers.json');
    final customers = <Map<String, dynamic>>[];
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          customers.addAll(decoded.whereType<Map<String, dynamic>>());
        }
      } catch (_) {
        throw const FormatException(
            'The customer index could not be read. It was preserved; restore it before updating contacts.');
      }
    }
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final key =
        normalizedPhone.isNotEmpty ? normalizedPhone : name.toLowerCase();
    final index = customers.indexWhere((customer) {
      final existingPhone =
          customer['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      final existingName = customer['name']?.toString().toLowerCase() ?? '';
      return normalizedPhone.isNotEmpty
          ? existingPhone == key
          : existingPhone.isEmpty && existingName == key;
    });
    final existing = index < 0 ? <String, dynamic>{} : customers[index];
    final invoices = (existing['invoices'] as List? ?? const [])
        .map((invoice) => invoice.toString())
        .toSet();
    final invoiceNumber = sale.invoiceNumber ?? sale.receiptNumber;
    final isNewBill = invoices.add(invoiceNumber);
    final next = <String, dynamic>{
      'id': existing['id']?.toString() ?? 'local-customer-$key',
      'name': name.isNotEmpty ? name : existing['name']?.toString() ?? '',
      'phone': phone.isNotEmpty ? phone : existing['phone']?.toString() ?? '',
      'email': existing['email']?.toString() ?? '',
      'addresses': existing['addresses'] ?? const [],
      'isActive': true,
      'createdAt':
          existing['createdAt']?.toString() ?? sale.createdAt.toIso8601String(),
      'orderCount': (existing['orderCount'] as num?)?.toInt() ?? 0,
      'orderValue':
          _number(existing['orderValue']) + (isNewBill ? sale.total : 0),
      'invoices': invoices.toList(growable: false),
    };
    if (isNewBill) next['orderCount'] = (next['orderCount'] as int) + 1;
    if (index < 0) {
      customers.add(next);
    } else {
      customers[index] = next;
    }
    await _replaceText(file, jsonEncode(customers));
    await _markWorkbookDirty(root);
  }

  static Future<void> saveCustomer(
      {required String name,
      required String phone,
      required String address,
      String email = ''}) async {
    final root = await _customerDirectory();
    return LocalBillingStore(rootPath: root).withLock(() async {
      if (name.trim().isEmpty ||
          address.trim().isEmpty ||
          validateNepalPhone(phone) != null) {
        throw const FormatException(
            'Enter name, address and a valid 10-digit phone number.');
      }
      final normalizedEmail = email.trim();
      if (normalizedEmail.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
        throw const FormatException(
            'Enter a valid email address or leave it empty.');
      }
      final file = File('$root/bill customer/customers.json');
      await file.parent.create(recursive: true);
      final records = <Map<String, dynamic>>[];
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! List) {
          throw const FormatException(
              'The customer file is invalid. Restore it before saving.');
        }
        records.addAll(decoded.cast<Map<String, dynamic>>());
      }
      final index =
          records.indexWhere((record) => record['phone'] == phone.trim());
      final previous = index < 0 ? <String, dynamic>{} : records[index];
      final next = <String, dynamic>{
        ...previous,
        'id': previous['id'] ?? 'local-customer-${phone.trim()}',
        'name': name.trim(),
        'phone': phone.trim(),
        'email': normalizedEmail,
        'addresses': [
          {'address': address.trim()}
        ],
        'isActive': true,
        'createdAt': previous['createdAt'] ?? DateTime.now().toIso8601String(),
      };
      if (index < 0) {
        records.add(next);
      } else {
        records[index] = next;
      }
      await _replaceText(file, jsonEncode(records));
      await _markWorkbookDirty(root);
    });
  }

  static Future<void> _markWorkbookDirty(String root) =>
      _dirtyWrites.run(() async {
        final file = File('$root/excel/export.pending');
        await file.parent.create(recursive: true);
        await file.writeAsString(DateTime.now().toUtc().toIso8601String(),
            flush: true);
      });

  /// The POS code is the stable key. Retries replace a snapshot, never append a
  /// second sale. This export is supplementary to the original financial record.
  static Future<void> recordSale(PosSale sale) async {
    final root = await _customerDirectory();
    final name = sale.receiptNumber;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,179}$').hasMatch(name)) {
      throw const FormatException(
          'A valid POS code is required for Excel export.');
    }
    final file = File('$root/excel/records/$name.json');
    await file.parent.create(recursive: true);
    await LocalBillingStore(rootPath: root).withLock(() async {
      await _replaceText(file, jsonEncode(sale.toReceiptJson()));
      await _markWorkbookDirty(root);
    });
  }

  /// Export already-cached online profiles as well as manually saved contacts.
  /// Credentials/authentication records are never part of this snapshot.
  static Future<void> recordCachedCustomers(
      List<AdminCustomer> customers) async {
    final root = await _customerDirectory();
    final rows = [
      for (final c in customers)
        {
          'id': c.id,
          'name': c.name,
          'phone': c.phone,
          'email': c.email,
          'addresses': c.addresses,
          'createdAt': c.createdAt,
          'orderCount': c.orderCount,
          'orderValue': c.orderValue,
          'isActive': c.isActive,
        }
    ]..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    final contents = jsonEncode(rows);
    final file = File('$root/excel/customers_cached.json');
    await file.parent.create(recursive: true);
    await LocalBillingStore(rootPath: root).withLock(() async {
      if (await file.exists() && await file.readAsString() == contents) return;
      await _replaceText(file, contents);
      await _markWorkbookDirty(root);
    });
  }

  /// A dirty marker survives restarts and Excel file locks. One workbook is
  /// generated per background pass, even when many old bills need backfilling.
  static Future<String?> refreshWorkbookIfNeeded() => _workbooks.run(() async {
        final root = await _customerDirectory();
        final dirty = File('$root/excel/export.pending');
        if (!await dirty.exists()) return null;
        final revision = await dirty.readAsString();
        final sheets = <String, List<List<Object?>>>{
          'Bills': [
            [
              'POS code',
              'Invoice number',
              'Date',
              'Customer name',
              'Customer phone',
              'Payment method',
              'Payment status',
              'Subtotal NPR',
              'Discount NPR',
              'VAT percent',
              'VAT NPR',
              'Total NPR',
              'Paid NPR',
              'Pending NPR',
              'Refunded NPR'
            ]
          ],
          'Bill items': [
            [
              'POS code',
              'Invoice number',
              'Product',
              'SKU',
              'Quantity',
              'Weight grams',
              'Unit price NPR',
              'Amount NPR'
            ]
          ],
          'Payments': [
            [
              'POS code',
              'Payment reference',
              'Date',
              'Method',
              'Amount NPR',
              'Note'
            ]
          ],
          'Customers': [
            [
              'Name',
              'Phone',
              'Email',
              'Address',
              'Created',
              'Number of bills',
              'Bill value NPR'
            ]
          ],
        };
        final balances = <String, List<String>>{};
        for (final name in ['pending_cash', 'pending_cash_local']) {
          final csv = File('$root/pending cash/$name.csv');
          if (!await csv.exists()) continue;
          final rows = _parseCsv(await csv.readAsString());
          sheets[name == 'pending_cash'
              ? 'Pending cash'
              : 'Pending cash local'] = [
            for (var i = 0; i < rows.length; i++)
              [
                for (var c = 0; c < rows[i].length; c++)
                  if (i > 0 && c >= 4 && c <= 6)
                    num.tryParse(rows[i][c]) ?? rows[i][c]
                  else
                    rows[i][c]
              ]
          ];
          // Preserve arbitrary manual columns/rows in the original CSV. Only
          // overlay known balance fields when their headers have not moved.
          if (rows.isNotEmpty &&
              rows.first.length >= 7 &&
              rows.first[0] == 'Invoice number' &&
              rows.first[5] == 'Paid' &&
              rows.first[6] == 'Cash pending') {
            for (final row in rows.skip(1).where((r) => r.length >= 8)) {
              balances[row[0]] = row;
            }
          }
        }
        final records = Directory('$root/excel/records');
        if (await records.exists()) {
          final files = await records
              .list()
              .where((f) => f is File && f.path.endsWith('.json'))
              .cast<File>()
              .toList();
          files.sort((a, b) => a.path.compareTo(b.path));
          for (final file in files) {
            final sale = PosSale.fromJson(
                jsonDecode(await file.readAsString()) as Map<String, dynamic>);
            final invoice = sale.invoiceNumber ?? sale.receiptNumber;
            final balance = balances[invoice];
            sheets['Bills']!.add([
              sale.receiptNumber,
              invoice,
              _exportDate(sale.createdAt),
              sale.customerName ?? '',
              sale.customerPhone ?? '',
              sale.paymentMethod,
              balance?[7] ?? sale.paymentStatus,
              sale.subtotal,
              sale.discount,
              sale.vatRate,
              sale.vatAmount,
              sale.total,
              balance == null ? _paid(sale) : _number(balance[5]),
              balance == null ? _due(sale) : _number(balance[6]),
              sale.refundedAmount
            ]);
            for (final item in sale.items) {
              sheets['Bill items']!.add([
                sale.receiptNumber,
                invoice,
                item.productName,
                item.sku,
                item.quantity,
                item.weightGrams,
                item.unitPrice,
                item.lineTotal
              ]);
            }
            for (final payment in sale.paymentCollections) {
              sheets['Payments']!.add([
                sale.receiptNumber,
                payment.id,
                _exportDate(payment.createdAt),
                payment.method,
                payment.amount,
                payment.note ?? ''
              ]);
            }
          }
        }
        final customerIndex = <String, Map<String, dynamic>>{};
        for (final path in [
          '$root/excel/customers_cached.json',
          '$root/bill customer/customers.json'
        ]) {
          final customers = File(path);
          if (!await customers.exists()) continue;
          for (final customer
              in (jsonDecode(await customers.readAsString()) as List)
                  .cast<Map<String, dynamic>>()) {
            final phone =
                '${customer['phone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
            final key = phone.isNotEmpty
                ? phone
                : '${customer['id'] ?? customer['name']}';
            final previous = customerIndex[key] ?? <String, dynamic>{};
            customerIndex[key] = {
              ...previous,
              ...customer,
              for (final field in ['name', 'email', 'phone'])
                if ('${customer[field] ?? ''}'.isEmpty &&
                    previous[field] != null)
                  field: previous[field],
              if ((customer['addresses'] as List? ?? []).isEmpty &&
                  previous['addresses'] != null)
                'addresses': previous['addresses'],
            };
          }
        }
        for (final customer in customerIndex.values) {
          sheets['Customers']!.add([
            customer['name'] ?? '',
            customer['phone'] ?? '',
            customer['email'] ?? '',
            (customer['addresses'] as List? ?? [])
                .map((a) => a is Map
                    ? a['address'] ??
                        a.entries
                            .where((e) => !{
                                  'id',
                                  'userId',
                                  'createdAt',
                                  'updatedAt',
                                  'isDefault'
                                }.contains(e.key))
                            .map((e) => '${e.key}: ${e.value}')
                            .join(', ')
                    : a)
                .join('; '),
            customer['createdAt'] ?? '',
            customer['orderCount'] ?? 0,
            _number(customer['orderValue'])
          ]);
        }
        sheets.putIfAbsent(
            'Pending cash',
            () => [
                  [
                    'Invoice number',
                    'Date',
                    'Customer name',
                    'Customer phone',
                    'Bill total',
                    'Paid',
                    'Cash pending',
                    'Payment status',
                    'Payment history'
                  ]
                ]);
        final bytes = await compute(buildBillingWorkbook, sheets);
        final file = File('$root/excel/FastStore_Billing.xlsx');
        final temporary = File('${file.path}.pending');
        try {
          await temporary.writeAsBytes(bytes, flush: true);
          if (await file.exists()) await file.copy('${file.path}.bak');
          await temporary.rename(file.path);
          // A concurrent new sale/customer leaves the marker for the next pass.
          await _dirtyWrites.run(() async {
            if (await dirty.exists() &&
                await dirty.readAsString() == revision) {
              await dirty.delete();
            }
          });
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
        return file.path;
      });

  static String _exportDate(DateTime date) {
    final n = date.toUtc().add(const Duration(hours: 5, minutes: 45));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.day)}/${two(n.month)}/${n.year} ${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  static Future<void> _replaceText(File file, String contents) async {
    final temp = File('${file.path}.pending');
    try {
      await temp.writeAsString(contents, flush: true);
      if (await file.exists()) await file.copy('${file.path}.bak');
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  static String _encode(List<List<String>> rows, {bool includeBom = true}) {
    final csv = rows.map((row) => row.join(',')).join('\r\n');
    return '${includeBom ? '\uFEFF' : ''}$csv\r\n';
  }

  static String _cell(String value, {bool protectFormula = false}) {
    var safe = value;
    if (protectFormula && RegExp(r'^[=+\-@\t\r]').hasMatch(safe)) {
      safe = "'$safe";
    }
    return '"${safe.replaceAll('"', '""')}"';
  }

  static double _paid(PosSale sale) => (sale.paidAmount ??
          (sale.paymentStatus == 'COMPLETED'
              ? sale.total
              : sale.paymentCollections.fold<double>(
                  0,
                  (sum, payment) => sum + payment.amount,
                )))
      .clamp(0, sale.total)
      .toDouble();

  static double _due(PosSale sale) =>
      (sale.outstandingAmount ?? sale.total - _paid(sale))
          .clamp(0, sale.total)
          .toDouble();

  static double _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}
