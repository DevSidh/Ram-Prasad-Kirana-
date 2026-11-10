import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/pos_models.dart';
import 'local_billing_store.dart';
import 'admin_api_service.dart';
import 'billing_excel_export_service.dart';
import 'bill_pdf_archive_service.dart';
import 'pos_receipt_service.dart';
import 'pos_timing.dart';
import 'offline_pos_store.dart';

/// Durable work is part of the local bill commit. Each independently retried
/// step is idempotent. Never retries a print: spooler delivery is ambiguous.
class BillingPostCommit {
  BillingPostCommit(this.store, this.api, this.ownerId,
      {this.catalog, this.onChanged});
  final VoidCallback? onChanged;
  int pendingTasks = 0;
  String? lastError;
  final OfflinePosStore? catalog;
  final LocalBillingStore store;
  final AdminApiService api;
  final String ownerId;
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  static Map<String, dynamic> tasks(PosSale sale, int width,
          {String? customerId}) =>
      {
        'receiptSnapshot': sale.toReceiptJson(),
        'receiptWidth': width,
        'receiptNepali': false,
        'postCommit': {
          'archive': false,
          'customer': false,
          'loyalty': customerId == null,
          'pendingCash': false,
          'excel': false,
          'prices': false
        },
        if (customerId != null) 'loyaltyCustomerId': customerId,
      };
  Future<void> enqueue(PosSale sale, int width) async {
    if (sale.localPath != null) {
      final record = await store.readJson(File(sale.localPath!));
      if (record['receiptWidth'] == width && record['receiptNepali'] == false) {
        return;
      }
    }
    final file = File(
        '${store.rootPath}/jobs/${BillPdfArchiveService.fileName(sale)}.$width.en.json');
    await store.withLock(() async {
      if (await file.exists()) return;
      await store.writeJson(file, {...tasks(sale, width), 'ownerId': ownerId});
    });
  }

  void start() {
    unawaited(run());
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(run()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  Future<void> run() async {
    if (_running || _disposed || ownerId.isEmpty) return;
    _running = true;
    pendingTasks = 0;
    lastError = null;
    try {
      final entries = await store.records();
      final jobs = Directory('${store.rootPath}/jobs');
      if (await jobs.exists()) {
        await for (final entity in jobs.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            try {
              entries.add((file: entity, record: await store.readJson(entity)));
            } catch (_) {/* Retain for repair. */}
          }
        }
      }
      entries.sort(
          (a, b) => '${a.record['date']}'.compareTo('${b.record['date']}'));
      for (final entry in entries) {
        if (_disposed) break;
        final record = entry.record;
        if (record['ownerId'] != ownerId ||
            record['postCommit'] is! Map ||
            record['receiptSnapshot'] is! Map) {
          continue;
        }
        final sale = PosSale.fromJson(
            Map<String, dynamic>.from(record['receiptSnapshot'] as Map));
        for (final task in [
          'archive',
          'customer',
          'pendingCash',
          'excel',
          'loyalty',
          'prices'
        ]) {
          if ((record['postCommit'] as Map)[task] == true) continue;
          pendingTasks++;
          try {
            switch (task) {
              case 'archive':
                final bytes = await PosReceiptService.createPdf(sale,
                    paperWidthMm: record['receiptWidth'] as int? ?? 58,
                    nepaliOverride: record['receiptNepali'] as bool?);
                await PosTiming.measure('archiving', () async {
                  await BillPdfArchiveService.save(sale, bytes);
                  if (record['invoiceNumber'] != null) {
                    final copy = File(
                        '${entry.file.parent.path}/${record['invoiceNumber']}.pdf');
                    final temp = File('${copy.path}.pending');
                    await temp.writeAsBytes(bytes, flush: true);
                    await temp.rename(copy.path);
                  }
                });
              case 'customer':
                if ((sale.customerName?.isNotEmpty ?? false) ||
                    (sale.customerPhone?.isNotEmpty ?? false)) {
                  await BillingExcelExportService.recordBillCustomer(sale);
                }
              case 'loyalty':
                if (record['loyaltyCustomerId'] is String) {
                  await api.recordOfflineStreakPurchase(
                      customerId: record['loyaltyCustomerId'] as String,
                      invoiceNumber: sale.invoiceNumber ?? sale.receiptNumber);
                }
              case 'pendingCash':
                final local = await store.records();
                await BillingExcelExportService.writePendingCash([],
                    localOnly: true,
                    localPendingRecords: [
                      for (final r in local)
                        {
                          'invoiceNumber': r.record['invoiceNumber'],
                          'date': r.record['date'],
                          'customerName': r.record['customerName'],
                          'customerPhone': r.record['customerPhone'],
                          'total': r.record['total'],
                          'paid': r.record['paidAmount'],
                          'due': r.record['outstandingAmount'],
                          'paymentStatus': r.record['paymentStatus'],
                        }
                    ]);
              case 'excel':
                await BillingExcelExportService.recordSale(sale);
              case 'prices':
                final changes = (record['cataloguePriceChanges'] as List?)
                    ?.cast<Map<String, dynamic>>();
                if (changes?.isNotEmpty == true) {
                  final resolved = <Map<String, dynamic>>[];
                  for (final change in changes!) {
                    final id = change['productId'] as String;
                    if (id.startsWith('offline-') ||
                        RegExp(r'^wholesale-\d+$').hasMatch(id)) {
                      final item =
                          sale.items.firstWhere((i) => i.productId == id);
                      final matches = (await api.searchPosProducts(item.sku))
                          .where((p) =>
                              p.sku.trim().toLowerCase() ==
                                  item.sku.trim().toLowerCase() &&
                              p.id.startsWith('wholesale-') ==
                                  id.startsWith('wholesale-') &&
                              !p.id.startsWith('offline-') &&
                              !RegExp(r'^wholesale-\d+$').hasMatch(p.id))
                          .toList();
                      if (matches.length != 1) {
                        throw StateError(
                            'Synchronize the new product before its price change. SKU must match exactly once.');
                      }
                      resolved.add({...change, 'productId': matches.single.id});
                    } else {
                      resolved.add(change);
                    }
                  }
                  await api.applyCataloguePriceChanges(
                      record['idempotencyKey'] as String, resolved);
                  if (catalog != null) {
                    for (final change in changes) {
                      final item = sale.items.firstWhere(
                          (i) => i.productId == change['productId']);
                      await catalog!
                          .mergeCatalog(await api.searchPosProducts(item.sku));
                    }
                  }
                }
            }
            await store.withLock(() async {
              final current = await store.readJson(entry.file);
              final errors = Map<String, dynamic>.from(
                  current['postCommitErrors'] as Map? ?? {})
                ..remove(task);
              await store.writeJson(entry.file, {
                ...current,
                'postCommit': {
                  ...Map<String, dynamic>.from(current['postCommit'] as Map),
                  task: true
                },
                'postCommitErrors': errors,
                'postCommitError': errors.isEmpty ? null : errors.values.first,
              });
            });
            pendingTasks--;
          } catch (error) {
            lastError = '$task: $error';
            await store.withLock(() async {
              final current = await store.readJson(entry.file);
              await store.writeJson(entry.file, {
                ...current,
                'postCommitErrors': {
                  ...Map<String, dynamic>.from(
                      current['postCommitErrors'] as Map? ?? {}),
                  task: '$error'
                },
                'postCommitError': '$task: $error'
              });
            });
          }
        }
      }
      if (!_disposed) {
        try {
          if (catalog != null) {
            await BillingExcelExportService.recordCachedCustomers(
                await catalog!.readCustomers());
          }
          await BillingExcelExportService.refreshWorkbookIfNeeded();
        } catch (error) {
          pendingTasks++;
          lastError = 'Excel export: $error. Close the workbook to retry.';
        }
      }
    } catch (error) {
      lastError = '$error';
      // Disk/permission errors leave the journal untouched for the next retry.
    } finally {
      _running = false;
      if (!_disposed) onChanged?.call();
    }
  }
}
