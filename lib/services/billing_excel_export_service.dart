import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../models/admin_models.dart';
import '../models/pos_models.dart';
import '../core/nepal_phone.dart';
import 'local_billing_store.dart';

/// Writes Excel-compatible CSV ledgers beside locally stored Windows bills.
class BillingExcelExportService {
  BillingExcelExportService._();

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
    final directory = Directory('$_baseDirectory/pending cash');
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
    await LocalBillingStore(rootPath: _baseDirectory).withLock(() async {
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
    return file.path;
  }

  static Future<String> recordBillCustomer(PosSale sale) async {
    final directory = Directory('$_baseDirectory/bill customer');
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
      LocalBillingStore(rootPath: _baseDirectory)
          .withLock(() => _upsertSavedCustomerUnlocked(sale));

  static Future<void> _upsertSavedCustomerUnlocked(PosSale sale) async {
    final name = sale.customerName?.trim() ?? '';
    final phone = sale.customerPhone?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) return;
    final directory = Directory('$_baseDirectory/bill customer');
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
    });
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
          sale.paymentCollections.fold<double>(
            0,
            (sum, payment) => sum + payment.amount,
          ))
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
