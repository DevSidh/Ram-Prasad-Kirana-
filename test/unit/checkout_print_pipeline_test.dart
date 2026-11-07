import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/bill_pdf_archive_service.dart';
import 'package:freshharvest_grocery/services/billing_excel_export_service.dart';
import 'package:freshharvest_grocery/services/billing_post_commit.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/services/pos_receipt_service.dart';
import 'package:freshharvest_grocery/services/receipt_print_service.dart';
import 'package:freshharvest_grocery/services/pos_timing.dart';

class _Api extends AdminApiService {
  _Api() : super(ApiService());
  int loyaltyCalls = 0;
  bool fail = true;
  bool failPrices = true;
  List<PosProduct> matches = [];
  List<Map<String, dynamic>>? priceChanges;
  @override
  Future<List<PosProduct>> searchPosProducts(String query) async => matches;
  @override
  Future<void> applyCataloguePriceChanges(
      String requestId, List<Map<String, dynamic>> changes) async {
    if (failPrices) { throw StateError('fixture price synchronization offline'); }
    priceChanges = changes;
  }

  @override
  Future<void> recordOfflineStreakPurchase(
      {required String customerId, required String invoiceNumber}) async {
    loyaltyCalls++;
    if (fail) throw StateError('fixture offline');
  }
}

class _Printer extends PrintingPlatform {
  int submissions = 0;
  Printer? lastPrinter;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canPrint: true, directPrint: true);
  @override
  Future<bool> layoutPdf(
      Printer? printer,
      LayoutCallback onLayout,
      String name,
      PdfPageFormat format,
      bool dynamicLayout,
      bool usePrinterSettings,
      OutputType outputType,
      bool forceCustomPrintPaper,
      bool windowsModernDialog) async {
    submissions++;
    lastPrinter = printer;
    final bytes = await onLayout(format);
    expect(format.width, closeTo(58 * PdfPageFormat.mm, .02));
    expect(bytes.length, greaterThan(1000));
    if (gate != null) await gate!.future;
    if (fail) throw StateError('fixture printer disconnected');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PosSale fixtureSale(
        {String id = 'POS-FIXTURE', String name = 'Bhujiya', int count = 1}) =>
    PosSale(
      id: id,
      receiptNumber: id,
      invoiceNumber: id,
      customerName: 'Fixture shopper',
      customerPhone: '9800000000',
      status: 'COMPLETED',
      paymentMethod: 'CASH',
      paymentStatus: 'PENDING',
      subtotal: count * 110,
      discount: 10,
      vatRate: 13,
      vatAmount: (count * 110 - 10) * .13,
      total: (count * 110 - 10) * 1.13,
      refundedAmount: 0,
      createdAt: DateTime(2026, 11, 6, 10, 30),
      paidAmount: 50,
      outstandingAmount: (count * 110 - 10) * 1.13 - 50,
      items: [
        PosSaleItem(
            id: 'i',
            productId: 'p',
            productName: name,
            sku: 'BHUJIYA',
            quantity: count,
            weightGrams: null,
            unitPrice: 110,
            lineTotal: count * 110)
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PrintingPlatform original;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('faststore-checkout-');
    PosReceiptService.cacheDirectoryOverride = Directory('${root.path}/cache');
    BillPdfArchiveService.rootOverride = '${root.path}/pdf';
    BillingExcelExportService.baseDirectoryOverride = root.path;
    PosTiming.logPath = null;
    PosTiming.samples.clear();
    PosReceiptService.clearMemoryCache();
    BillingStrings.languageCode = 'en';
    original = PrintingPlatform.instance;
  });
  tearDown(() async {
    await Directory('tmp/pdfs').create(recursive: true);
    if (PosTiming.samples.containsKey('print_submission')) {
      await File('tmp/pdfs/print-fixture-timing.json').writeAsString(jsonEncode(PosTiming.samples));
    }
    if (PosTiming.samples.containsKey('archiving')) {
      await File('tmp/pdfs/archive-fixture-timing.json').writeAsString(jsonEncode(PosTiming.samples));
    }
    PrintingPlatform.instance = original;
    PosReceiptService.clearMemoryCache();
    PosReceiptService.cacheDirectoryOverride = null;
    BillPdfArchiveService.rootOverride = null;
    BillingExcelExportService.baseDirectoryOverride = null;
    await root.delete(recursive: true);
  });
  test(
      'one PDF for concurrent printing/archive, disk cache survives restart and checks corruption',
      () async {
    final sale = fixtureSale();
    final results = await Future.wait(List.generate(
        3, (_) => PosReceiptService.createPdf(sale, paperWidthMm: 58)));
    expect(results[0], orderedEquals(results[2]));
    expect(PosTiming.samples['receipt_generation']!.length, 1);
    BillingStrings.languageCode = 'ne';
    expect(await PosReceiptService.createPdf(sale, paperWidthMm: 58, nepaliOverride: false), orderedEquals(results[0]));
    BillingStrings.languageCode = 'en';
    PosReceiptService.clearMemoryCache();
    expect(await PosReceiptService.createPdf(sale, paperWidthMm: 58),
        orderedEquals(results[0]));
    expect(PosTiming.samples['receipt_generation']!.length, 1);
    final cached =
        (await PosReceiptService.cacheDirectoryOverride!.list().toList())
            .whereType<File>()
            .firstWhere((f) => f.path.endsWith('.pdf'));
    await cached.writeAsString('damaged');
    PosReceiptService.clearMemoryCache();
    await PosReceiptService.createPdf(sale, paperWidthMm: 58);
    expect(PosTiming.samples['receipt_generation']!.length, 2);
    await PosReceiptService.createPdf(sale, paperWidthMm: 80);
    expect(PosTiming.samples['receipt_generation']!.length, 3);
  });
  test(
      'selected printer, duplicate click, failure and reprint use the saved sale',
      () async {
    final printer = _Printer()..gate = Completer<void>();
    PrintingPlatform.instance = printer;
    await (await SharedPreferences.getInstance()).setString(
        ReceiptPrintService.preferenceKey,
        jsonEncode(const Printer(url: 'usb-fixture', name: 'Deli ES301 fixture')
            .toMap()));
    final sale = fixtureSale();
    final first = ReceiptPrintService.print(sale, 58);
    final duplicate = ReceiptPrintService.print(sale, 58);
    printer.gate!.complete();
    expect(await first, true);
    expect(await duplicate, true);
    expect(printer.submissions, 1);
    expect(printer.lastPrinter!.url, 'usb-fixture');
    printer.fail = true;
    await expectLater(ReceiptPrintService.print(sale, 58), throwsStateError);
    printer.fail = false;
    expect(await ReceiptPrintService.print(sale, 58), true);
    expect(PosTiming.samples['receipt_generation']!.length, 1);
    expect(sale.receiptNumber, 'POS-FIXTURE');
  });
  test(
      'financial commit survives offline post-processing and a new worker retries only unfinished tasks',
      () async {
    final store = LocalBillingStore(rootPath: root.path);
    final api = _Api();
    final sale = fixtureSale(count: 10);
    const key = '550e8400-e29b-41d4-a716-446655440000';
    final file = await store.saveBill(
        record: {
          ...BillingPostCommit.tasks(sale, 58, customerId: 'fixture-customer'),
          'date': sale.createdAt.toIso8601String(),
          'items': sale.toReceiptJson()['items'],
          'total': sale.total,
          'paidAmount': 50,
          'outstandingAmount': sale.outstandingAmount,
          'paymentStatus': 'PENDING',
          'cataloguePriceChanges': [
            {'productId': 'p', 'expectedPrice': 100, 'price': 110}
          ],
        },
        requestId: key,
        ownerId: 'fixture',
        queueForSync: false,
        uploadPayload: {});
    expect((await store.readJson(file))['total'], sale.total);
    expect((await store.pendingCataloguePrices())['p'], 110);
    final worker = BillingPostCommit(store, api, 'fixture');
    await worker.run();
    worker.dispose();
    var record = await store.readJson(file);
    expect(record['postCommit']['archive'], true);
    expect(record['postCommit']['loyalty'], false);
    expect(record['postCommit']['prices'], false);
    api.fail = false;
    final restart = BillingPostCommit(store, api, 'fixture');
    await restart.run();
    restart.dispose();
    record = await store.readJson(file);
    expect(record['postCommit']['loyalty'], true);
    expect(api.loyaltyCalls, 2);
    expect((await store.records()).length, 1);
    expect(record['total'], sale.total);
    expect(PosTiming.samples['receipt_generation']!.length, 1);
    final local = OfflinePosStore(
        billingStore: store, useLocalStock: true, storageDirectory: root);
    expect(local.billingStore.rootPath, root.path);
    await store.updateLocalBill(file, {...record,
      'paidAmount': sale.total, 'outstandingAmount': 0, 'paymentStatus': 'COMPLETED'}, expectedPaidAmount: 50);
    final collected = await store.readJson(file);
    expect(collected['postCommit']['archive'], false);
    expect(collected['postCommit']['pendingCash'], false);
    expect(collected['receiptSnapshot']['paidAmount'], sale.total);
    expect(collected['receiptSnapshot']['outstandingAmount'], 0);
    final afterCollection = BillingPostCommit(store, api, 'fixture');
    await afterCollection.run(); afterCollection.dispose();
    expect((await store.readJson(file))['postCommit']['archive'], true);
    expect((await store.readJson(file))['postCommit']['pendingCash'], true);
    expect(PosTiming.samples['receipt_generation']!.length, 2);
  });
  test('new offline products wait for an unambiguous server SKU before syncing an edited price', () async {
    final store = LocalBillingStore(rootPath: root.path);
    final api = _Api()..failPrices = false;
    final json = fixtureSale().toReceiptJson();
    (json['items'] as List).first['productId'] = 'offline-123';
    final sale = PosSale.fromJson(json);
    final file = await store.saveBill(record: {
      ...BillingPostCommit.tasks(sale, 58),
      'postCommit': {'archive': true, 'customer': true, 'pendingCash': true, 'loyalty': true, 'prices': false},
      'date': sale.createdAt.toIso8601String(), 'items': json['items'], 'total': sale.total,
      'cataloguePriceChanges': [{'productId': 'offline-123', 'expectedPrice': 100, 'price': 110}],
    }, requestId: '550e8400-e29b-41d4-a716-446655440002', ownerId: 'fixture', queueForSync: false, uploadPayload: {});
    final worker = BillingPostCommit(store, api, 'fixture');
    await worker.run();
    expect(api.priceChanges, isNull);
    expect((await store.readJson(file))['postCommit']['prices'], false);
    api.matches = [const PosProduct(id: 'p', name: 'Bhujiya', sku: 'BHUJIYA', barcode: null, price: 100, unitLabel: 'pcs', available: 20)];
    await worker.run(); worker.dispose();
    expect(api.priceChanges, [{'productId': 'p', 'expectedPrice': 100, 'price': 110}]);
    expect((await store.readJson(file))['postCommit']['prices'], true);
  });
}
