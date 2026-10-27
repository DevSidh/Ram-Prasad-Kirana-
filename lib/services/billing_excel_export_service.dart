import 'dart:io';

import '../models/pos_models.dart';

/// Writes Excel-compatible CSV ledgers beside locally stored Windows bills.
class BillingExcelExportService {
  BillingExcelExportService._();

  static const _baseDirectory = 'C:/Ramprasad store/bills';

  static Future<String> writePendingCash(
    List<PosSale> sales, {
    List<Map<String, dynamic>> localPendingRecords = const [],
  }) async {
    final directory = Directory('$_baseDirectory/pending cash');
    await directory.create(recursive: true);
    final file = File('${directory.path}/pending_cash.csv');
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
    await file.writeAsString(_encode(rows), flush: true);
    return file.path;
  }

  static Future<String> recordBillCustomer(PosSale sale) async {
    final directory = Directory('$_baseDirectory/bill customer');
    await directory.create(recursive: true);
    final file = File('${directory.path}/bill_customers.csv');
    final exists = await file.exists();
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
    return file.path;
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
