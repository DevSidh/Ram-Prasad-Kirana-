import '../../widgets/billing_localized_widgets.dart';
import '../../models/stock_summary.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/nepal_phone.dart';
import '../../models/pos_models.dart';
import '../../models/room_inventory.dart';
import '../../services/room_inventory_service.dart';
import '../../widgets/room_pick_dialog.dart';
import '../../models/manual_fonepay_verification.dart';
import '../../widgets/static_fonepay_payment_dialog.dart';
import '../../widgets/offline_customer_dialog.dart';
import '../../models/admin_models.dart';
import '../../models/scanned_product_barcode.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/billing_excel_export_service.dart';
import '../../services/bill_pdf_archive_service.dart';
import '../../services/billing_customer_service.dart';
import '../../services/offline_pos_store.dart';
import '../../services/local_billing_store.dart';
import '../../services/local_billing_sync.dart';
import '../../services/ordered_work_queue.dart';
import '../../widgets/local_billing_status_panel.dart';
import '../../services/pos_receipt_service.dart';
import '../../services/receipt_print_service.dart';
import '../../services/billing_post_commit.dart';
import '../../services/pos_timing.dart';
import '../../services/store_audio_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/product_identity.dart';
import 'barcode_scanner_screen.dart';
import 'admin_billing_staff_screen.dart';
import '../auth/login_screen.dart';

const _pendingLocalStreaksPreferenceKey = 'pending_local_streak_receipts_v1';

String _paymentNoteLabel(String note) {
  final manual = ManualFonepayVerification.fromNote(note);
  final provider = manual?.provider == 'ESEWA' ? 'eSewa' : 'eSewa';
  return manual == null
      ? note
      : manual.isCashierConfirmation
          ? '$provider payment received - confirmed by cashier ${manual.cashierId}'
          : 'Manual $provider verification · Reference ${manual.transactionReference} · Cashier ${manual.cashierId}';
}

enum AdminBillingSection {
  dashboard,
  essential,
  barcodeScanner,
  heldBills,
  billHistory,
  payments,
  pendingPayments,
  cashRegister,
  customers,
  returns,
  reports,
  printer,
  notifications,
}

double _roundBillMoney(double value) => (value * 100).round() / 100;

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({
    super.key,
    required this.api,
    this.isBillingStaff = false,
    this.offlineStore = const OfflinePosStore(),
  });

  final ApiService api;
  final bool isBillingStaff;
  final OfflinePosStore offlineStore;

  @override
  State<AdminBillingScreen> createState() => AdminBillingScreenState();
}

class AdminBillingScreenState extends State<AdminBillingScreen>
    with WidgetsBindingObserver {
  static const _barcodePairingCodePreferenceKey =
      'admin_billing_barcode_pairing_code';
  bool get _isWindowsOperatorMode =>
      !widget.isBillingStaff &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;

  late final AdminApiService _adminApi = AdminApiService(widget.api);
  PosOverview? _overview;
  PosOverview? _reportOverview;
  List<PosSale> _sales = const [];
  List<AdminCustomer> _localBillingCustomers = const [];
  PosSalesPage? _pendingPaymentPage;
  List<PosSale> _localPendingSales = const [];
  int _salesPage = 1;
  int _salesPageSize = 50;
  int _salesTotal = 0;
  int _pendingPaymentPageNumber = 1;
  final _billHistorySearchController = TextEditingController();
  final _pendingPaymentSearchController = TextEditingController();
  String _pendingPaymentDayKey = '';
  final _refundSearchController = TextEditingController();
  String _refundDayKey = '';
  List<PosRefund> _refunds = const [];
  List<PosHeldSale> _heldSales = const [];
  List<PosExchange> _exchanges = const [];
  String? _exchangeError;
  DateTime? _billHistoryDay;
  String _billHistorySearch = '';
  DateTime? _reportDay;
  bool _loading = true;
  String? _error;
  bool _sessionExpired = false;
  int _loadRequestId = 0;
  bool _working = false;
  String? _barcodePairingCode;
  bool _syncingPendingCashExport = false;
  LocalBillingSync? _localBillingSync;
  bool _offlineOverview = false;
  int _paperWidthMm = 80;
  AdminBillingSection _activeSection = AdminBillingSection.dashboard;
  final _scrollController = ScrollController();
  final _customerSearch = TextEditingController();
  final _returnsSearch = TextEditingController();
  DateTime? _returnsDay;
  List<PosSale>? _returnSales;
  List<PosExchange>? _returnExchanges;
  Timer? _returnsTimer;
  int _returnsRequest = 0;
  bool _returnsLoading = false;
  String? _returnsError;
  final _barcodeSearch = TextEditingController();
  List<PosProduct> _barcodeMatches = const [];
  final _sectionKeys = <AdminBillingSection, GlobalKey>{
    for (final section in AdminBillingSection.values) section: GlobalKey(),
  };

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _border => Theme.of(context).colorScheme.outlineVariant;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;

  BillingPostCommit? _postCommit;
  String? _printerName;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _postCommit?.dispose();
    _localBillingSync?.dispose();
    _scrollController.dispose();
    _customerSearch.dispose();
    _returnsSearch.dispose();
    _returnsTimer?.cancel();
    _barcodeSearch.dispose();
    _billHistorySearchController.dispose();
    _pendingPaymentSearchController.dispose();
    _refundSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isWindowsOperatorMode ||
        ![
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.detached
        ].contains(state)) {
      return;
    }
    final sync = _localBillingSync;
    if (sync != null) {
      unawaited(sync.synchronize().timeout(
            const Duration(seconds: 4),
            onTimeout: () {},
          ));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPaperWidth());
    unawaited(_syncPendingLocalStreaks());
    unawaited(_load());
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      PosTiming.logPath =
          '${widget.offlineStore.billingStore.rootPath}/diagnostics/checkout-timing.jsonl';
      _postCommit = BillingPostCommit(widget.offlineStore.billingStore,
          _adminApi, context.read<AuthProvider>().currentUser?.id ?? '',
          catalog: widget.offlineStore, onChanged: () {
        if (mounted) setState(() {});
      })
        ..start();
      unawaited(ReceiptPrintService.selected().then((p) {
        if (mounted) setState(() => _printerName = p?.name);
      }));
    }
    if (_isWindowsOperatorMode) {
      _localBillingSync = LocalBillingSync(
        api: widget.api,
        store: widget.offlineStore.billingStore,
        catalogStore: widget.offlineStore,
        ownerId: context.read<AuthProvider>().currentUser?.id ?? '',
        onSynced: _load,
      )..start();
    }
  }

  Future<void> _syncPendingLocalStreaks() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final pending =
          preferences.getStringList(_pendingLocalStreaksPreferenceKey) ?? [];
      final remaining = <String>[];
      for (final entry in pending) {
        final value = jsonDecode(entry);
        if (value is! Map<String, dynamic> ||
            value['customerId'] is! String ||
            value['invoiceNumber'] is! String) {
          continue;
        }
        try {
          await _adminApi.recordOfflineStreakPurchase(
            customerId: value['customerId'] as String,
            invoiceNumber: value['invoiceNumber'] as String,
          );
        } catch (_) {
          remaining.add(entry);
        }
      }
      await preferences.setStringList(
        _pendingLocalStreaksPreferenceKey,
        remaining,
      );
    } catch (_) {
      // Local bills are independent from streak synchronization.
    }
  }

  Future<void> _loadBarcodePairingCode() async {
    if (!_isWindowsOperatorMode || _barcodePairingCode != null) return;
    final preferences = await SharedPreferences.getInstance();
    _barcodePairingCode =
        preferences.getString(_barcodePairingCodePreferenceKey);
  }

  Future<void> _storeBarcodePairingCode(String? code) async {
    _barcodePairingCode = code;
    final preferences = await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await preferences.remove(_barcodePairingCodePreferenceKey);
    } else {
      await preferences.setString(_barcodePairingCodePreferenceKey, code);
    }
  }

  Future<void> _loadPaperWidth() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final width = preferences.getInt('pos_receipt_paper_width_mm');
      if (!mounted || width == null) return;
      if (width != 58 && width != 80) return;
      setState(() => _paperWidthMm = width);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            'Could not load receipt paper settings: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _setPaperWidth(int width) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('pos_receipt_paper_width_mm', width);
      if (mounted) setState(() => _paperWidthMm = width);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            'Could not save paper width: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  String? _formatDayKey(DateTime? day) {
    if (day == null) return null;
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  String? get _billHistoryDayKey => _formatDayKey(_billHistoryDay);

  List<PosSale> get _visibleSales {
    final query = _billHistorySearch.trim().toLowerCase();
    if (query.isEmpty) return _sales;
    return _sales.where((sale) {
      return (sale.invoiceNumber ?? sale.receiptNumber)
              .toLowerCase()
              .contains(query) ||
          (sale.customerName ?? '').toLowerCase().contains(query) ||
          (sale.customerPhone ?? '').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  String? get _reportDayKey => _formatDayKey(_reportDay);

  Future<void> _seedWindowsBillingFromLocal({
    required int requestId,
    required int salesPage,
    required int pendingPage,
  }) async {
    if (!_isWindowsOperatorMode) return;
    try {
      final values = await Future.wait<Object?>([
        widget.offlineStore.readCachedBillsPage(page: salesPage),
        widget.offlineStore.readCachedRefunds(),
        widget.offlineStore.readCachedPendingPayments(page: pendingPage),
        widget.offlineStore.readOfflineSales(),
      ]);
      if (!mounted || requestId != _loadRequestId) return;
      final cachedPage = values[0] as PosSalesPage?;
      final cachedRefunds = values[1] as List<PosRefund>?;
      final cachedPending = values[2] as PosSalesPage?;
      final fileSales = values[3] as List<PosSale>;
      final cachedSales = <String, PosSale>{
        for (final sale in cachedPage?.sales ?? const <PosSale>[])
          sale.invoiceNumber ?? sale.receiptNumber: sale,
        for (final sale in fileSales)
          sale.invoiceNumber ?? sale.receiptNumber: sale,
      }.values.where((sale) {
        if (_billHistoryDayKey != null &&
            _formatDayKey(sale.createdAt.toLocal()) != _billHistoryDayKey) {
          return false;
        }
        final query = _billHistorySearchController.text.trim().toLowerCase();
        return query.isEmpty ||
            (sale.invoiceNumber ?? sale.receiptNumber)
                .toLowerCase()
                .contains(query) ||
            (sale.customerName ?? '').toLowerCase().contains(query) ||
            (sale.customerPhone ?? '').toLowerCase().contains(query);
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _sales = cachedSales;
        _salesPage = cachedPage?.page ?? salesPage;
        _salesPageSize = cachedPage?.pageSize ?? _salesPageSize;
        _salesTotal =
            cachedPage == null ? cachedSales.length : cachedPage.total;
        if (cachedRefunds != null) _refunds = cachedRefunds;
        if (cachedPending != null) {
          _pendingPaymentPage = cachedPending;
          _pendingPaymentPageNumber = cachedPending.page;
        }
        _localPendingSales = fileSales
            .where((sale) =>
                sale.id.startsWith('local-') &&
                sale.paymentStatus == 'PENDING' &&
                (sale.outstandingAmount ?? 0) > 0)
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      // Keep the existing network and file fallbacks if SQLite is unavailable.
    }
  }

  Future<void> _load({int? salesPage, int? pendingPage}) async {
    unawaited(_loadLocalBillingCustomers());
    final requestId = ++_loadRequestId;
    final requestedSalesPage = salesPage ?? _salesPage;
    final requestedPendingPage = pendingPage ?? _pendingPaymentPageNumber;
    setState(() {
      _loading = true;
      _error = null;
      _sessionExpired = false;
    });
    await _seedWindowsBillingFromLocal(
      requestId: requestId,
      salesPage: requestedSalesPage,
      pendingPage: requestedPendingPage,
    );
    try {
      // Start all independent dashboard requests together. Previously the
      // overview request completed before the remaining requests even began,
      // adding a full network round trip to every refresh.
      final results = await Future.wait([
        _adminApi.getPosOverview(),
        if (_reportDayKey != null) _adminApi.getPosOverview(day: _reportDayKey),
        _adminApi.getPosSales(
          page: requestedSalesPage,
          day: _billHistoryDayKey,
          search: _billHistorySearchController.text.trim(),
        ),
        if (widget.isBillingStaff)
          Future<List<PosRefund>>.value(const [])
        else
          _adminApi.getPosRefunds(
            search: _refundSearchController.text.trim(),
            day: _refundDayKey.isEmpty ? null : _refundDayKey,
          ),
        _adminApi.getPosHeldSales(),
        _adminApi.getPosPendingPayments(
          page: requestedPendingPage,
          search: _pendingPaymentSearchController.text.trim(),
          day: _pendingPaymentDayKey.isEmpty ? null : _pendingPaymentDayKey,
        ),
      ]);
      List<PosExchange> exchanges = const [];
      String? exchangeError;
      try {
        exchanges = await _adminApi.getPosExchanges();
      } catch (error) {
        exchangeError = error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted || requestId != _loadRequestId) return;
      final overview = results[0] as PosOverview;
      final reportOverview =
          _reportDayKey == null ? overview : results[1] as PosOverview;
      final salesIndex = _reportDayKey == null ? 1 : 2;
      final loadedSalesPage = results[salesIndex] as PosSalesPage;
      final localSales = _isWindowsOperatorMode
          ? await widget.offlineStore.readOfflineSales()
          : const <PosSale>[];
      if (!mounted || requestId != _loadRequestId) return;
      final filteredLocalSales = _billHistoryDayKey == null
          ? localSales
          : localSales.where((sale) =>
              _formatDayKey(sale.createdAt.toLocal()) == _billHistoryDayKey);
      final onlineInvoiceNumbers = loadedSalesPage.sales
          .map((sale) => sale.invoiceNumber ?? sale.receiptNumber)
          .toSet();
      final uniqueLocalSales = filteredLocalSales
          .where((sale) => !onlineInvoiceNumbers
              .contains(sale.invoiceNumber ?? sale.receiptNumber))
          .toList(growable: false);
      final mergedSales = <PosSale>[
        ...loadedSalesPage.sales,
        ...uniqueLocalSales
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _offlineOverview = false;
        _overview = overview;
        _reportOverview = reportOverview;
        _sales = mergedSales;
        _salesPage = loadedSalesPage.page;
        _salesPageSize = loadedSalesPage.pageSize;
        _salesTotal = loadedSalesPage.total + uniqueLocalSales.length;
        _refunds = results[salesIndex + 1] as List<PosRefund>;
        _heldSales = results[salesIndex + 2] as List<PosHeldSale>;
        _pendingPaymentPage = results[salesIndex + 3] as PosSalesPage;
        _localPendingSales = localSales
            .where((sale) =>
                sale.id.startsWith('local-') &&
                sale.paymentStatus == 'PENDING' &&
                (sale.outstandingAmount ?? 0) > 0)
            .toList(growable: false);
        _pendingPaymentPageNumber =
            (results[salesIndex + 3] as PosSalesPage).page;
        _exchanges = exchanges;
        _exchangeError = exchangeError;
        _loading = false;
      });
      if (_isWindowsOperatorMode) unawaited(_syncPendingCashExport());
    } catch (error) {
      var localSales = const <PosSale>[];
      if (_isWindowsOperatorMode) {
        try {
          localSales = await widget.offlineStore.readOfflineSales();
        } catch (localReadError) {
          debugPrint('Could not read local billing history: $localReadError');
        }
      }
      if (!mounted || requestId != _loadRequestId) return;
      final sessionExpired =
          error is ApiResponseException && error.statusCode == 401;
      setState(() {
        _offlineOverview = true;
        _sales = localSales;
        _localPendingSales = localSales
            .where((sale) => sale.paymentStatus == 'PENDING')
            .toList(growable: false);
        _salesTotal = localSales.length;
        if (_isWindowsOperatorMode) {
          _overview ??= PosOverview.fromJson(
            const <String, dynamic>{'metrics': <String, dynamic>{}},
          );
          _reportOverview ??= _overview;
        }
        _sessionExpired = sessionExpired;
        _error = sessionExpired
            ? 'Your sign-in session has expired. Sign in again to reconnect.'
            : error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _signInAgain() async {
    try {
      await context.read<AuthProvider>().logout();
    } catch (error) {
      debugPrint('Could not clear expired billing session: $error');
    }
    if (!mounted) return;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          isWindowsStaffLogin: isWindows,
          isAdminLogin: !isWindows && !widget.isBillingStaff,
          isBillingLogin: !isWindows && widget.isBillingStaff,
        ),
      ),
      (_) => false,
    );
  }

  Widget _loadErrorAction() => _sessionExpired
      ? TextButton.icon(
          onPressed: _signInAgain,
          icon: const Icon(Icons.login_rounded),
          label: const BillingText('Sign in again'),
        )
      : TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const BillingText('Retry'),
        );

  Future<void> _newBill(
      {PosHeldSale? heldSale, PosProduct? scannedProduct}) async {
    final completedSale = await showDialog<PosSale>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PosBillDialog(
        offlineStore: widget.offlineStore,
        api: _adminApi,
        heldSale: heldSale,
        scannedProduct: scannedProduct,
        onScan: _scanProduct,
        onNewBill: startNewBill,
        operatorId: context.read<AuthProvider>().currentUser?.id ?? '',
        allowOfflineSync: _isWindowsOperatorMode,
        allowPriceEditing: !widget.isBillingStaff,
        localSync: _localBillingSync,
        printSale: _printManuallyVerifiedBill,
        paperWidthMm: _paperWidthMm,
      ),
    );
    if (!mounted) return;
    if (completedSale == null) return;
    _showCommittedSaleImmediately(completedSale);
    if (_localBillingSync != null && completedSale.id.startsWith('local-')) {
      unawaited(_localBillingSync!.synchronize());
    }
    // The financial commit has finished. Report it before preparing a receipt.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: BillingText('Bill saved: ${completedSale.receiptNumber}')));
    unawaited(StoreAudioService.playConfirmation());
    var printMessage = 'Bill saved.';
    try {
      if (_postCommit != null) {
        await _postCommit!.enqueue(completedSale, _paperWidthMm);
      }
      if (completedSale.autoPrintAllowed &&
          defaultTargetPlatform == TargetPlatform.windows) {
        final printed = await _printManuallyVerifiedBill(completedSale);
        printMessage = printed
            ? 'Bill saved. Receipt submitted to printer.'
            : 'Bill saved. Printing cancelled. Use Reprint Bill.';
      } else if (completedSale.autoPrintAllowed &&
          ['FONEPAY', 'ESEWA'].contains(completedSale.paymentMethod)) {
        await _printOrShareInvoice(completedSale);
      }
    } catch (error) {
      printMessage =
          'Bill saved. Printing needs attention: ${error.toString().replaceFirst('Exception: ', '')}. Use Reprint Bill.';
    } finally {
      unawaited(_postCommit?.run());
      unawaited(_load());
      unawaited(_localBillingSync?.synchronize());
      if (_isWindowsOperatorMode) unawaited(_syncPendingCashExport());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: BillingText(printMessage)));
  }

  void _showCommittedSaleImmediately(PosSale sale) {
    if (!mounted) return;
    final key = sale.invoiceNumber ?? sale.receiptNumber;
    final existing = _sales.indexWhere(
        (item) => (item.invoiceNumber ?? item.receiptNumber) == key);
    final updated = [..._sales];
    if (existing >= 0) {
      updated[existing] = sale;
    } else {
      updated.insert(0, sale);
    }
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pending =
        sale.paymentStatus == 'PENDING' && (sale.outstandingAmount ?? 0) > 0;
    setState(() {
      _sales = updated;
      _salesTotal = _salesTotal < updated.length ? updated.length : _salesTotal;
      if (pending) {
        final pendingSales = [..._localPendingSales];
        final index = pendingSales.indexWhere(
            (item) => (item.invoiceNumber ?? item.receiptNumber) == key);
        if (index >= 0) {
          pendingSales[index] = sale;
        } else {
          pendingSales.insert(0, sale);
        }
        _localPendingSales = pendingSales;
      }
    });
  }

  void startNewBill() {
    unawaited(_newBill());
  }

  Future<bool> _printManuallyVerifiedBill(PosSale sale) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: BillingText('Bill saved. Preparing receipt…')));
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await _postCommit?.enqueue(sale, _paperWidthMm);
      if (await ReceiptPrintService.selected() == null && mounted) {
        final chosen = await ReceiptPrintService.choose(context);
        if (chosen == null) return false;
        if (mounted) setState(() => _printerName = chosen.name);
      }
      try {
        return await ReceiptPrintService.print(sale, _paperWidthMm);
      } finally {
        unawaited(_postCommit?.run());
      }
    }
    final bytes = await PosReceiptService.createInvoicePdf(sale);
    await BillPdfArchiveService.save(sale, bytes);
    return Printing.layoutPdf(
        name: BillPdfArchiveService.fileName(sale),
        onLayout: (_) async => bytes);
  }

  Future<void> _syncPendingCashExport({bool showMessage = false}) async {
    if (!_isWindowsOperatorMode || _syncingPendingCashExport) return;
    _syncingPendingCashExport = true;
    try {
      final pendingHistory = <PosSale>[];
      var serverUnavailable = false;
      var page = 1;
      var pageCount = 1;
      try {
        do {
          final result = await _adminApi.getPosSales(page: page, pageSize: 100);
          pendingHistory.addAll(result.sales.where((sale) =>
              sale.paymentStatus == 'PENDING' ||
              sale.paymentCollections.isNotEmpty));
          pageCount = result.pageCount;
          page++;
        } while (page <= pageCount);
      } catch (_) {
        serverUnavailable = true;
        pendingHistory.clear();
      }

      final localPendingRecords = <Map<String, dynamic>>[];
      final billsDirectory = Directory('C:/Ramprasad store/bills');
      if (await billsDirectory.exists()) {
        await for (final entity in billsDirectory.list(followLinks: false)) {
          if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
            continue;
          }
          try {
            final decoded = await const LocalBillingStore().readJson(entity);
            if (decoded['syncState'] == 'synced') {
              continue;
            }
            final total = (decoded['total'] as num?)?.toDouble() ?? 0;
            final paid = (decoded['paidAmount'] as num?)?.toDouble() ?? 0;
            if (total <= 0) continue;
            localPendingRecords.add({
              'invoiceNumber': decoded['invoiceNumber'],
              'date': decoded['date'],
              'customerName': decoded['customerName'],
              'customerPhone': decoded['customerPhone'],
              'total': total,
              'paid': paid,
              'due': (total - paid).clamp(0, total),
              'paymentStatus': decoded['paymentStatus'],
            });
          } catch (_) {
            // Ignore malformed local bill files and keep exporting valid bills.
          }
        }
      }
      final path = await BillingExcelExportService.writePendingCash(
        pendingHistory,
        localPendingRecords: localPendingRecords,
        localOnly: serverUnavailable,
      );
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: BillingText('Pending cash Excel file saved to $path')),
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: BillingText(
              'Could not update pending cash Excel file: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      _syncingPendingCashExport = false;
    }
  }

  void openBarcodeScanner() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      startNewBill();
      return;
    }
    unawaited(() async {
      final product = await _scanProduct();
      if (product != null && mounted) await _newBill(scannedProduct: product);
    }());
  }

  void activateSection(AdminBillingSection section) {
    if (section == AdminBillingSection.returns) unawaited(_loadReturns());
    if (_isWindowsOperatorMode) {
      setState(() => _activeSection = section);
      return;
    }
    final key = _sectionKeys[section];
    if (key == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (targetContext == null || !mounted) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
  }

  Future<PosProduct?> _scanProduct() async {
    await _loadBarcodePairingCode();
    if (!mounted) return null;
    final scanned = await Navigator.of(context).push<ScannedProductBarcode>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          api: _adminApi,
          existingPairingCode: _barcodePairingCode,
          onPairingCodeChanged: (code) =>
              unawaited(_storeBarcodePairingCode(code)),
        ),
      ),
    );
    if (scanned == null || !mounted) return null;
    try {
      final cached = await widget.offlineStore.searchCatalog(scanned.value);
      final cachedExact = cached.where((product) =>
          product.barcode?.toLowerCase() == scanned.value.toLowerCase() ||
          product.sku.toLowerCase() == scanned.value.toLowerCase() ||
          product.id == scanned.value);
      if (cachedExact.isNotEmpty) return mounted ? cachedExact.first : null;
      final matches = await _adminApi.searchPosProducts(scanned.value);
      final exact = matches.where((product) =>
          product.barcode?.toLowerCase() == scanned.value.toLowerCase() ||
          product.sku.toLowerCase() == scanned.value.toLowerCase() ||
          product.id == scanned.value);
      final product = exact.isNotEmpty
          ? exact.first
          : matches.length == 1
              ? matches.first
              : null;
      if (!mounted) return null;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: BillingText('No product matched that barcode.')),
        );
      }
      return product;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                BillingText(error.toString().replaceFirst('Exception: ', ''))),
      );
      return null;
    }
  }

  Future<void> _cashMovement(String type) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: BillingText(
            type == 'CASH_IN' ? 'Add cash to register' : 'Remove cash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const BillingInputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: noteController,
              maxLength: 240,
              decoration:
                  const BillingInputDecoration(labelText: 'Reason / note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const BillingText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const BillingText('Record'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      amountController.dispose();
      noteController.dispose();
      return;
    }
    final amount = double.tryParse(amountController.text.trim());
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();
    if (amount == null || amount <= 0 || note.isEmpty) {
      _showMessage('Enter a positive amount and a note.');
      return;
    }
    await _perform(() => _adminApi.recordPosCashMovement(
          type: type,
          amount: amount,
          note: note,
        ));
  }

  Future<void> _requestRefund(PosSale sale) async {
    final refundable = ((sale.paidAmount ??
                (sale.paymentStatus == 'COMPLETED' ? sale.total : 0)) -
            sale.refundedAmount)
        .clamp(0, sale.total)
        .toDouble();
    if (refundable <= 0) {
      _showMessage('No received funds remain available for refund.');
      return;
    }
    final amountController = TextEditingController(
      text: refundable.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    var restock = false;
    String? validationError;
    final values =
        await showDialog<({double amount, String reason, bool restock})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: BillingText('Refund ${sale.receiptNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BillingText(
                  'Received funds available for refund: ${_money(refundable)}'),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const BillingInputDecoration(labelText: 'Refund amount'),
              ),
              TextField(
                controller: reasonController,
                maxLength: 500,
                decoration: const BillingInputDecoration(labelText: 'Reason'),
              ),
              if (sale.refundedAmount == 0 && refundable >= sale.total)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: restock,
                  title: const BillingText('Restore all bill items to stock'),
                  onChanged: (value) =>
                      setDialogState(() => restock = value ?? false),
                ),
              if (validationError != null)
                BillingText(validationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const BillingText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final reason = reasonController.text.trim();
                if (amount == null ||
                    !amount.isFinite ||
                    amount < 0.01 ||
                    amount > refundable ||
                    reason.length < 2 ||
                    (restock && _roundBillMoney(amount) != sale.total)) {
                  setDialogState(() => validationError =
                      'Enter a valid received-funds amount and reason. Restocking all items requires a full refund.');
                  return;
                }
                Navigator.pop(dialogContext, (
                  amount: amount,
                  reason: reason,
                  restock: restock,
                ));
              },
              child: const BillingText('Submit request'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    reasonController.dispose();
    if (values == null) return;
    await _perform(() => _adminApi.createPosRefund(
          saleId: sale.id,
          amount: values.amount,
          reason: values.reason,
          restockStock: values.restock,
        ));
  }

  Future<void> _openExchange(PosSale sale) async {
    if (sale.items.isEmpty) return;
    var returnedItem = sale.items.first;
    var restockReturnedItems = true;
    var paymentMethod = 'CASH';
    var replacementSearchError = '';
    var matches = <PosProduct>[];
    PosProduct? replacementProduct;
    var searchRequest = 0;
    final returnedQuantityController = TextEditingController(
      text: '${returnedItem.weightGrams ?? returnedItem.quantity}',
    );
    final replacementQuantityController = TextEditingController(text: '1');
    final searchController = TextEditingController();

    final draft = await showDialog<
        ({
          PosSaleItem returnedItem,
          int returnedQuantity,
          PosProduct? replacementProduct,
          int replacementQuantity,
          bool restock,
          String? paymentMethod,
        })>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final weightedReturn = returnedItem.weightGrams != null;
          final returnedQuantity =
              int.tryParse(returnedQuantityController.text.trim()) ?? 0;
          final replacementQuantity =
              int.tryParse(replacementQuantityController.text.trim()) ?? 0;
          final replacement = replacementProduct;
          final discountFactor =
              sale.subtotal > 0 ? sale.total / sale.subtotal : 1.0;
          final returnedCredit = returnedItem.unitPrice *
              (weightedReturn ? returnedQuantity / 1000 : returnedQuantity) *
              discountFactor;
          final replacementTotal = replacement == null
              ? 0.0
              : replacement.price *
                  (StockSummary.isLooseWeight(replacement)
                      ? replacementQuantity / 1000
                      : replacementQuantity);
          final difference = replacementTotal - returnedCredit;
          final replacementIsWeighted =
              replacement != null && StockSummary.isLooseWeight(replacement);
          return AlertDialog(
            title: BillingText('Exchange ${sale.receiptNumber}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<PosSaleItem>(
                      isExpanded: true,
                      initialValue: returnedItem,
                      decoration: const BillingInputDecoration(
                          labelText: 'Item to return'),
                      items: sale.items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: ProductIdentity(
                                  name: '${item.productName} · ${item.sku}',
                                  productId: item.productId,
                                  sku: item.sku,
                                  store: widget.offlineStore,
                                  size: 36),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (item) {
                        if (item == null) return;
                        setDialogState(() {
                          returnedItem = item;
                          returnedQuantityController.text =
                              '${item.weightGrams ?? item.quantity}';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: returnedQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: BillingInputDecoration(
                        labelText: weightedReturn
                            ? 'Return weight (grams)'
                            : 'Return quantity',
                        helperText: weightedReturn
                            ? 'Sold ${returnedItem.weightGrams} g'
                            : 'Sold ${returnedItem.quantity}',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: BillingInputDecoration(
                        labelText: 'Replacement product (optional)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: replacementProduct == null
                            ? null
                            : BillingIconButton(
                                tooltip: 'Clear replacement',
                                onPressed: () => setDialogState(() {
                                  replacementProduct = null;
                                  searchController.clear();
                                  matches = [];
                                }),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      onChanged: (query) {
                        final request = ++searchRequest;
                        if (query.trim().length < 2) {
                          setDialogState(() {
                            matches = [];
                            replacementSearchError = '';
                          });
                          return;
                        }
                        unawaited(() async {
                          try {
                            final products =
                                await _adminApi.searchPosProducts(query.trim());
                            if (!dialogContext.mounted ||
                                request != searchRequest) {
                              return;
                            }
                            setDialogState(() {
                              matches = products;
                              replacementSearchError = '';
                            });
                          } catch (error) {
                            if (!dialogContext.mounted ||
                                request != searchRequest) {
                              return;
                            }
                            setDialogState(() {
                              replacementSearchError = error
                                  .toString()
                                  .replaceFirst('Exception: ', '');
                            });
                          }
                        }());
                      },
                    ),
                    if (replacementSearchError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: BillingText(
                          replacementSearchError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (matches.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final product = matches[index];
                            return ListTile(
                              dense: true,
                              leading: ProductThumbnail(
                                  imageUrl: product.imageUrl ?? '', size: 48),
                              title: BillingText(product.name),
                              subtitle: BillingText(product.isUnlimited
                                  ? '${product.sku} - ${_money(product.price)} - Unlimited stock'
                                  : '${product.sku} - ${_money(product.price)} - ${product.available} available'),
                              /*
                              subtitle: BillingText(
                                '${product.sku} · ${_money(product.price)} · '
                                product.isUnlimited
                                    ? 'Unlimited stock'
                                    : '${product.available} available',
                              ),
                              */
                              onTap: !product.isUnlimited &&
                                      product.available <= 0
                                  ? null
                                  : () => setDialogState(() {
                                        replacementProduct = product;
                                        searchController.text = product.name;
                                        matches = [];
                                        replacementQuantityController.text =
                                            StockSummary.isLooseWeight(product)
                                                ? '1000'
                                                : '1';
                                      }),
                            );
                          },
                        ),
                      ),
                    if (replacementProduct != null) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: replacementQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: BillingInputDecoration(
                          labelText: replacementIsWeighted
                              ? 'Replacement weight (grams)'
                              : 'Replacement quantity',
                          helperText:
                              '${replacementProduct!.name} · ${_money(replacementProduct!.price)} per '
                              '${replacementIsWeighted ? 'kg' : 'unit'}',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: restockReturnedItems,
                      onChanged: (value) => setDialogState(
                        () => restockReturnedItems = value ?? false,
                      ),
                      title: const BillingText('Return item to sellable stock'),
                    ),
                    const SizedBox(height: 8),
                    BillingText(
                      difference > 0
                          ? 'Customer pays ${_money(difference)} extra.'
                          : difference < 0
                              ? 'Refund of ${_money(-difference)} needs admin approval. Keep the item and do not issue the replacement until approved.'
                              : 'No additional payment or refund is due.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (difference > 0) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: paymentMethod,
                        decoration: const BillingInputDecoration(
                          labelText: 'Additional payment method',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CASH',
                            child: BillingText('Cash'),
                          ),
                          DropdownMenuItem(
                            value: 'DIGITAL',
                            child: BillingText('Digital'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => paymentMethod = value);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const BillingText('Cancel'),
              ),
              FilledButton(
                onPressed: returnedQuantity <= 0 ||
                        returnedQuantity >
                            (returnedItem.weightGrams ??
                                returnedItem.quantity) ||
                        (replacementProduct != null &&
                            (replacementQuantity <= 0 ||
                                replacementQuantity >
                                    replacementProduct!.available))
                    ? null
                    : () => Navigator.pop(
                          dialogContext,
                          (
                            returnedItem: returnedItem,
                            returnedQuantity: returnedQuantity,
                            replacementProduct: replacementProduct,
                            replacementQuantity: replacementQuantity,
                            restock: restockReturnedItems,
                            paymentMethod:
                                difference > 0 ? paymentMethod : null,
                          ),
                        ),
                child: const BillingText('Process exchange'),
              ),
            ],
          );
        },
      ),
    );
    returnedQuantityController.dispose();
    replacementQuantityController.dispose();
    searchController.dispose();
    if (draft == null || !mounted) return;

    final selectedReturn = draft.returnedItem;
    final weightedReturn = selectedReturn.weightGrams != null;
    final selectedReplacement = draft.replacementProduct;
    final replacementWeighted = selectedReplacement != null &&
        StockSummary.isLooseWeight(selectedReplacement);
    setState(() => _working = true);
    try {
      final exchange = await _adminApi.createPosExchange(
        saleId: sale.id,
        idempotencyKey: const Uuid().v4(),
        returnedItems: [
          {
            'saleItemId': selectedReturn.id,
            if (weightedReturn)
              'weightGrams': draft.returnedQuantity
            else
              'quantity': draft.returnedQuantity,
          },
        ],
        replacementItems: selectedReplacement == null
            ? const []
            : [
                {
                  'productId': selectedReplacement.id,
                  if (replacementWeighted)
                    'weightGrams': draft.replacementQuantity
                  else
                    'quantity': draft.replacementQuantity,
                },
              ],
        restockReturnedItems: draft.restock,
        paymentMethod: draft.paymentMethod,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final message = exchange.status == 'REFUND_REQUESTED'
          ? 'Exchange saved. The refund difference is awaiting admin approval.'
          : exchange.difference > 0
              ? 'Exchange completed; ${_money(exchange.difference)} collected.'
              : 'Exchange completed.';
      _showMessage(message);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _perform(Future<Object?> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await operation();
      if (!mounted) return;
      await _load();
      if (mounted) _showMessage('Billing data updated.');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: BillingText(message)));
  }

  Future<void> _selectHistoryDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _billHistoryDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      _billHistoryDay = selected;
      _salesPage = 1;
    });
    await _load(salesPage: 1);
  }

  Future<void> _searchBillHistory() async {
    setState(() => _salesPage = 1);
    await _load(salesPage: 1);
  }

  Future<void> _selectPendingPaymentDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _pendingPaymentDayKey.isEmpty
          ? DateTime.now()
          : DateTime.parse(_pendingPaymentDayKey),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      _pendingPaymentDayKey = _formatDayKey(selected)!;
      _pendingPaymentPageNumber = 1;
    });
    await _load(pendingPage: 1);
  }

  Future<void> _selectRefundDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _refundDayKey.isEmpty
          ? DateTime.now()
          : DateTime.parse(_refundDayKey),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() => _refundDayKey = _formatDayKey(selected)!);
    await _load();
  }

  Future<void> _selectReportDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _reportDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() => _reportDay = selected);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final loadedOverview = _overview;
    if (loadedOverview == null && _error != null && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BillingText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              _sessionExpired
                  ? FilledButton.icon(
                      onPressed: _signInAgain,
                      icon: const Icon(Icons.login_rounded),
                      label: const BillingText('Sign in again'),
                    )
                  : FilledButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                      label: const BillingText('Retry'),
                    ),
            ],
          ),
        ),
      );
    }
    final overview = loadedOverview ??
        PosOverview.fromJson(const <String, dynamic>{
          'metrics': <String, dynamic>{},
        });
    final reportOverview = _reportOverview ?? overview;

    if (_isWindowsOperatorMode) {
      return _buildWindowsOperatorPage(overview, reportOverview);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(8, 8, 30, 36),
            children: [
              Container(
                key: _sectionKeys[AdminBillingSection.dashboard],
                child: _buildHeader(overview),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                MaterialBanner(
                  content: BillingText(_error!),
                  actions: [_loadErrorAction()],
                ),
              Container(
                key: _sectionKeys[AdminBillingSection.cashRegister],
                child: _buildCashRegisterCard(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('Today’s sales', _money(overview.totalSales),
                      Icons.payments_outlined),
                  _metric('Bills completed', '${overview.completedBills}',
                      Icons.receipt_long_outlined),
                  _metric('Average bill', _money(overview.averageBillValue),
                      Icons.show_chart_rounded),
                  _metric('Cash received', _money(overview.cashSales),
                      Icons.point_of_sale_outlined),
                  _metric('Digital', _money(overview.digitalSales),
                      Icons.account_balance_wallet_outlined),
                  _metric('Pending', _money(overview.pendingSales),
                      Icons.pending_actions_outlined),
                  if (!widget.isBillingStaff) ...[
                    _metric('Refunds', _money(overview.refunds),
                        Icons.currency_exchange_rounded),
                    _metric('Cancelled', '${overview.cancelledBills}',
                        Icons.cancel_outlined),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              _sectionHeading(
                'Quick actions',
                key: _sectionKeys[AdminBillingSection.essential],
                actions: [
                  FilledButton.icon(
                    onPressed: _working ? null : () => _newBill(),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const BillingText('New bill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ||
                            defaultTargetPlatform == TargetPlatform.windows
                        ? null
                        : () async {
                            final product = await _scanProduct();
                            if (product != null && mounted) {
                              await _newBill(scannedProduct: product);
                            }
                          },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const BillingText('Scan barcode'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showDailyReport,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const BillingText('Daily report'),
                  ),
                  if (!widget.isBillingStaff && !_isWindowsOperatorMode)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminBillingStaffScreen(api: widget.api),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const BillingText('Billing staff'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                key: _sectionKeys[AdminBillingSection.heldBills],
                child: _buildHeldBills(),
              ),
              const SizedBox(height: 20),
              _sectionHeading(
                'Invoice Management',
                key: _sectionKeys[AdminBillingSection.billHistory],
                actions: [
                  FilledButton.icon(
                    onPressed: _working ? null : () => _newBill(),
                    icon: const Icon(Icons.add_rounded),
                    label: const BillingText('New bill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _exportSalesCsv,
                    icon: const Icon(Icons.download_outlined),
                    label: const BillingText('Export CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectHistoryDay,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: BillingText(_billHistoryDayKey ?? 'All days'),
                  ),
                  if (_billHistoryDay != null)
                    BillingIconButton(
                      tooltip: 'Clear date filter',
                      onPressed: () {
                        setState(() {
                          _billHistoryDay = null;
                          _salesPage = 1;
                        });
                        unawaited(_load(salesPage: 1));
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              _buildInvoiceManagementToolbar(),
              if (_salesTotal > _salesPageSize)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BillingText(
                        '${((_salesPage - 1) * _salesPageSize) + 1}–'
                        '${(_salesPage * _salesPageSize).clamp(0, _salesTotal)}'
                        ' of $_salesTotal bills',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      BillingIconButton(
                        tooltip: 'Previous bills page',
                        onPressed: _loading || _salesPage <= 1
                            ? null
                            : () => _load(salesPage: _salesPage - 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      BillingIconButton(
                        tooltip: 'Next bills page',
                        onPressed: _loading ||
                                _salesPage >=
                                    (_salesTotal / _salesPageSize).ceil()
                            ? null
                            : () => _load(salesPage: _salesPage + 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              if (_visibleSales.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: BillingText('No invoices found.'),
                )
              else
                ..._visibleSales.map(_saleTile),
              const SizedBox(height: 20),
              _sectionHeading(
                'Offline customers',
                key: _sectionKeys[AdminBillingSection.customers],
              ),
              _buildCustomers(),
              const SizedBox(height: 20),
              Column(
                key: _sectionKeys[AdminBillingSection.reports],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading(
                    'Sales report · ${reportOverview.day}',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: _selectReportDay,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: BillingText(_reportDayKey ?? 'Today'),
                      ),
                      if (_reportDay != null)
                        BillingIconButton(
                          tooltip: 'Show today’s report',
                          onPressed: () {
                            setState(() => _reportDay = null);
                            unawaited(_load());
                          },
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                  _buildInsights(reportOverview),
                ],
              ),
              const SizedBox(height: 20),
              _buildNotifications(),
              const SizedBox(height: 20),
              Container(
                key: _sectionKeys[AdminBillingSection.returns],
                child: _buildReturnsAndRefunds(),
              ),
              const SizedBox(height: 20),
              Container(
                key: _sectionKeys[AdminBillingSection.pendingPayments],
                child: _buildPendingPayments(),
              ),
              const SizedBox(height: 20),
              Container(
                key: _sectionKeys[AdminBillingSection.payments],
                child: _buildPayments(),
              ),
              const SizedBox(height: 14),
              Container(
                key: _sectionKeys[AdminBillingSection.printer],
                child: _printerSettings(overview),
              ),
              BillingText(
                'Connected · synced ${TimeOfDay.fromDateTime(DateTime.now()).format(context)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (_working)
          Positioned.fill(
            child: ColoredBox(
              color: (AppColors.isWindowsAdminDarkTheme
                      ? Colors.black
                      : AppColors.primary)
                  .withValues(alpha: 0.13),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildWindowsOperatorPage(
    PosOverview overview,
    PosOverview reportOverview,
  ) {
    final sections = <Widget>[
      if (_localBillingSync != null)
        LocalBillingStatusPanel(sync: _localBillingSync!),
      if (_error != null)
        MaterialBanner(
          content: BillingText(_error!),
          actions: [_loadErrorAction()],
        ),
      if (_offlineOverview &&
          [
            AdminBillingSection.dashboard,
            AdminBillingSection.reports,
            AdminBillingSection.cashRegister
          ].contains(_activeSection)) ...[
        const SizedBox(height: 12),
        const BillingText(
            'Server reports are unavailable. The figures below include only saved local bills.'),
        _metric(
            'Local recorded sales',
            _money(_sales
                .where((sale) =>
                    sale.localPath != null && sale.status != 'CANCELLED')
                .fold<double>(0, (sum, sale) => sum + sale.total)),
            Icons.computer_outlined),
        FilledButton.icon(
            onPressed: () => _newBill(),
            icon: const Icon(Icons.add),
            label: const BillingText('New bill')),
        _buildInvoiceManagementToolbar(),
        ..._visibleSales.map(_saleTile),
      ] else
        ..._windowsOperatorSectionContent(overview, reportOverview),
      const SizedBox(height: 28),
    ];
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: ValueKey('billing-page-${_activeSection.name}'),
            padding: const EdgeInsets.fromLTRB(8, 8, 30, 36),
            children: sections,
          ),
        ),
        if (_working)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.13),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  List<Widget> _windowsOperatorSectionContent(
    PosOverview overview,
    PosOverview reportOverview,
  ) {
    switch (_activeSection) {
      case AdminBillingSection.dashboard:
        return [
          _buildHeader(overview),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('Today’s sales', _money(overview.totalSales),
                  Icons.payments_outlined),
              _metric('Bills completed', '${overview.completedBills}',
                  Icons.receipt_long_outlined),
              _metric('Average bill', _money(overview.averageBillValue),
                  Icons.show_chart_rounded),
              _metric('Cash received', _money(overview.cashSales),
                  Icons.point_of_sale_outlined),
              _metric('Digital', _money(overview.digitalSales),
                  Icons.account_balance_wallet_outlined),
              _metric('Pending', _money(overview.pendingSales),
                  Icons.pending_actions_outlined),
              _metric('Refunds', _money(overview.refunds),
                  Icons.currency_exchange_rounded),
              _metric('Cancelled', '${overview.cancelledBills}',
                  Icons.cancel_outlined),
            ],
          ),
          const SizedBox(height: 20),
          _sectionHeading('Recent invoices'),
          if (_visibleSales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BillingText('No invoices found.'),
            )
          else
            ..._visibleSales.take(5).map(_saleTile),
        ];
      case AdminBillingSection.essential:
        return [_buildWindowsEssentialPage()];
      case AdminBillingSection.barcodeScanner:
        return [_buildWindowsBarcodePage()];
      case AdminBillingSection.heldBills:
        return [_buildHeldBills()];
      case AdminBillingSection.billHistory:
        return [
          _sectionHeading(
            'Invoice Management',
            actions: [
              FilledButton.icon(
                onPressed: _working ? null : () => _newBill(),
                icon: const Icon(Icons.add_rounded),
                label: const BillingText('New bill'),
              ),
            ],
          ),
          _buildInvoiceManagementToolbar(),
          if (_salesTotal > _salesPageSize) _buildSalesPagination(),
          if (_visibleSales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BillingText('No invoices found.'),
            )
          else
            ..._visibleSales.map(_saleTile),
        ];
      case AdminBillingSection.payments:
        return [_buildPayments()];
      case AdminBillingSection.pendingPayments:
        return [_buildPendingPayments()];
      case AdminBillingSection.cashRegister:
        return [
          _buildCashRegisterCard(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('Cash received', _money(overview.cashSales),
                  Icons.payments_outlined),
              _metric('Digital payments', _money(overview.digitalSales),
                  Icons.phone_android_rounded),
              _metric('Today’s sales', _money(overview.totalSales),
                  Icons.show_chart_rounded),
            ],
          ),
        ];
      case AdminBillingSection.customers:
        return [
          _sectionHeading('Offline customers'),
          _buildCustomers(),
        ];
      case AdminBillingSection.returns:
        return [_buildReturnsAndRefunds()];
      case AdminBillingSection.reports:
        return [
          _sectionHeading(
            'Sales report · ${reportOverview.day}',
            actions: [
              OutlinedButton.icon(
                onPressed: _selectReportDay,
                icon: const Icon(Icons.calendar_today_outlined),
                label: BillingText(_reportDayKey ?? 'Today'),
              ),
              if (_reportDay != null)
                BillingIconButton(
                  tooltip: 'Show today’s report',
                  onPressed: () {
                    setState(() => _reportDay = null);
                    unawaited(_load());
                  },
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          _buildInsights(reportOverview),
        ];
      case AdminBillingSection.printer:
        return [_printerSettings(overview)];
      case AdminBillingSection.notifications:
        return [_buildNotifications()];
    }
  }

  Widget _buildWindowsEssentialPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Essential billing actions',
            actions: [
              FilledButton.icon(
                onPressed: _working ? null : () => _newBill(),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const BillingText('New bill'),
              ),
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () => activateSection(AdminBillingSection.barcodeScanner),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const BillingText('Barcode scanner'),
              ),
              OutlinedButton.icon(
                onPressed: _showDailyReport,
                icon: const Icon(Icons.analytics_outlined),
                label: const BillingText('Daily report'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCashRegisterCard(),
        ],
      );

  Widget _buildWindowsBarcodePage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Barcode scanner'),
          const SizedBox(height: 8),
          BillingText(
            'Scan a product with a USB or Bluetooth barcode scanner, or type its barcode or SKU.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeSearch,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchWindowsBarcode(),
                  decoration: const BillingInputDecoration(
                    labelText: 'Scan or enter barcode / SKU',
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _working ? null : _searchWindowsBarcode,
                icon: const Icon(Icons.search_rounded),
                label: const BillingText('Find product'),
              ),
            ],
          ),
          if (_barcodeMatches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: BillingText('Scanned products will appear here.'),
            )
          else ...[
            const SizedBox(height: 16),
            for (final product in _barcodeMatches)
              AppRowCard(
                title: product.name,
                subtitle: '${product.sku} · ${_money(product.price)}',
                leading: ProductThumbnail(
                    imageUrl: product.imageUrl ?? '', size: 52),
                trailing: FilledButton(
                  onPressed:
                      _working ? null : () => _newBill(scannedProduct: product),
                  child: const BillingText('Add to bill'),
                ),
              ),
          ],
        ],
      );

  Future<void> _searchWindowsBarcode() async {
    final barcode = _barcodeSearch.text.trim();
    if (barcode.isEmpty || _working) return;
    setState(() {
      _working = true;
      _barcodeMatches = const [];
    });
    try {
      final matches = await _adminApi.searchPosProducts(barcode);
      if (!mounted) return;
      final exact = matches.where((product) =>
          product.barcode?.toLowerCase() == barcode.toLowerCase() ||
          product.sku.toLowerCase() == barcode.toLowerCase() ||
          product.id == barcode);
      setState(() => _barcodeMatches =
          exact.isNotEmpty ? exact.toList(growable: false) : matches);
      if (_barcodeMatches.isEmpty) {
        _showMessage('No product matched that barcode or SKU.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _buildSalesPagination() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BillingText(
              '${((_salesPage - 1) * _salesPageSize) + 1}–'
              '${(_salesPage * _salesPageSize).clamp(0, _salesTotal)}'
              ' of $_salesTotal bills',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            BillingIconButton(
              tooltip: 'Previous bills page',
              onPressed: _loading || _salesPage <= 1
                  ? null
                  : () => _load(salesPage: _salesPage - 1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            BillingIconButton(
              tooltip: 'Next bills page',
              onPressed: _loading ||
                      _salesPage >= (_salesTotal / _salesPageSize).ceil()
                  ? null
                  : () => _load(salesPage: _salesPage + 1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );

  Widget _buildHeader(PosOverview overview) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: BillingText(
            '${overview.cashierName ?? 'Admin'} · '
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        BillingIconButton(
          tooltip: 'Refresh billing',
          onPressed: _working ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCashRegisterCard() {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.point_of_sale_rounded),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BillingText(
                  'Cash register',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                BillingText(
                  'Record cash added to or taken from the drawer.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _working ? null : () => _cashMovement('CASH_IN'),
            child: const BillingText('Cash in'),
          ),
          OutlinedButton(
            onPressed: _working ? null : () => _cashMovement('CASH_OUT'),
            child: const BillingText('Cash out'),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return AppStatCard(
      label: title,
      value: value,
      icon: icon,
      tint: AppColors.thumbnailGreen,
    );
  }

  Widget _sectionHeading(
    String title, {
    List<Widget> actions = const [],
    Key? key,
  }) {
    return Wrap(
      key: key,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        AppSectionLabel(title),
        ...actions,
      ],
    );
  }

  Future<void> _loadLocalBillingCustomers() async {
    final customers =
        await BillingCustomerService.readLocal(widget.offlineStore);
    if (mounted) setState(() => _localBillingCustomers = customers);
  }

  Future<void> _addOfflineCustomer() async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OfflineCustomerDialog());
    if (saved == true && mounted) await _loadLocalBillingCustomers();
  }

  Future<void> _showCustomerBills(AdminCustomer customer) async {
    final phone = BillingCustomerService.phoneKey(customer.phone);
    bool matches(PosSale sale) => phone.isNotEmpty
        ? BillingCustomerService.phoneKey(sale.customerPhone ?? '') == phone
        : (sale.customerPhone?.trim().isEmpty ?? true) &&
            sale.customerName?.trim().toLowerCase() ==
                customer.name.trim().toLowerCase();
    Future<({List<PosSale> bills, String? warning})> load() async {
      final all = <String, PosSale>{};
      void add(Iterable<PosSale> bills) {
        for (final sale in bills.where(matches)) {
          all[sale.invoiceNumber ?? sale.receiptNumber] = sale;
        }
      }

      add(_sales);
      add(await widget.offlineStore.readOfflineSales());
      String? warning;
      try {
        var page = 1;
        while (true) {
          final result = await _adminApi.getPosSales(
              page: page,
              pageSize: 100,
              search: phone.isNotEmpty ? phone : customer.name);
          add(result.sales);
          if (page >= result.pageCount || result.sales.isEmpty) break;
          page++;
        }
      } catch (_) {
        warning =
            'Server history is unavailable. Showing saved bills on this computer.';
      }
      final bills = all.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return (bills: bills, warning: warning);
    }

    final history = load();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: BillingText(customer.name),
              content: SizedBox(
                  width: 650,
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SelectableText(customer.phone),
                        if (customer.email.isNotEmpty)
                          SelectableText(customer.email),
                        for (final address in customer.addresses)
                          SelectableText(address['address']?.toString() ?? ''),
                        const SizedBox(height: 16),
                        const BillingText('Customer bills',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        FutureBuilder<({List<PosSale> bills, String? warning})>(
                            future: history,
                            builder: (_, snapshot) {
                              if (snapshot.hasError) {
                                return BillingText(
                                    'Could not load bills: ${snapshot.error}');
                              }
                              if (!snapshot.hasData) {
                                return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator());
                              }
                              final data = snapshot.data!;
                              return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (data.warning != null)
                                      BillingText(data.warning!),
                                    if (data.bills.isEmpty)
                                      const BillingText(
                                          'No bills saved for this customer yet.'),
                                    ...data.bills.map(_saleTile),
                                  ]);
                            }),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const BillingText('Close'))
              ],
            ));
  }

  Widget _buildCustomers() {
    final customers = <String, List<PosSale>>{};
    for (final sale in _sales) {
      final key = sale.customerPhone?.trim().isNotEmpty == true
          ? sale.customerPhone!.trim()
          : sale.customerName?.trim() ?? '';
      if (key.isNotEmpty) customers.putIfAbsent(key, () => []).add(sale);
    }
    final query = _customerSearch.text.trim().toLowerCase();
    final contacts = BillingCustomerService.merge([
      ..._localBillingCustomers,
      ...customers.entries.map((entry) {
        final sale = entry.value.first;
        return AdminCustomer(
            id: 'local-customer-${entry.key}',
            profileId: '',
            name: sale.customerName ?? 'Customer',
            email: '',
            phone: sale.customerPhone ?? '',
            isActive: true,
            createdAt: sale.createdAt.toIso8601String(),
            orderCount: entry.value.length,
            orderValue: entry.value
                .fold<double>(0, (total, sale) => total + sale.total),
            addresses: const [],
            recentOrders: const []);
      }),
    ]);
    final visibleCustomers = contacts.where((customer) {
      if (query.isEmpty) return true;
      return customer.name.toLowerCase().contains(query) ||
          BillingCustomerService.phoneKey(customer.phone).contains(query);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
                onPressed: _addOfflineCustomer,
                icon: const Icon(Icons.person_add_alt_1),
                label: const BillingText('New customer'))),
        TextField(
          controller: _customerSearch,
          decoration: const BillingInputDecoration(
            labelText: 'Search billing customers by name or phone',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (visibleCustomers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: BillingText(
              contacts.isEmpty
                  ? 'Customer details captured during checkout will appear here.'
                  : 'No billing customers match that search.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...visibleCustomers.map((customer) {
            final name = customer.name.trim();
            final phone = customer.phone.trim();
            final totalSpend = customer.orderValue;
            return ListTile(
              onTap: () => _showCustomerBills(customer),
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
              title: BillingText(name.isNotEmpty ? name : 'Customer'),
              subtitle: BillingText(
                '${phone.isNotEmpty ? phone : 'No phone saved'} · '
                '${customer.orderCount} bill${customer.orderCount == 1 ? '' : 's'}',
              ),
              trailing: BillingText(_money(totalSpend)),
            );
          }),
      ],
    );
  }

  Widget _buildNotifications() {
    final pendingPayments =
        _sales.where((sale) => sale.paymentStatus == 'PENDING').length;
    final pendingRefunds =
        _refunds.where((refund) => refund.status == 'REQUESTED').length;
    final pendingExchangeRefunds = _exchanges
        .where((exchange) => exchange.status == 'REFUND_REQUESTED')
        .length;
    final lowStockCount = _overview?.lowStock.length ?? 0;
    final messages = <String>[
      if (_error != null) 'System alert: $_error',
      if (lowStockCount > 0)
        '$lowStockCount active product(s) are low on stock.',
      if (_heldSales.isNotEmpty) '${_heldSales.length} bill(s) are on hold.',
      if (pendingPayments > 0) '$pendingPayments bill(s) are awaiting payment.',
      if (pendingRefunds > 0)
        '$pendingRefunds refund request(s) need admin review.',
      if (pendingExchangeRefunds > 0)
        '$pendingExchangeRefunds exchange refund(s) are waiting for admin approval.',
    ];
    return Container(
      key: _sectionKeys[AdminBillingSection.notifications],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Notifications'),
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BillingText(
                'You are all caught up.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            ...messages.map(
              (message) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: BillingText(message),
              ),
            ),
        ],
      ),
    );
  }

  String? get _returnsDayKey => _returnsDay == null
      ? null
      : '${_returnsDay!.year}-${_returnsDay!.month.toString().padLeft(2, '0')}-${_returnsDay!.day.toString().padLeft(2, '0')}';

  Future<void> _loadReturns() async {
    if (!mounted) return;
    final request = ++_returnsRequest;
    final query = _returnsSearch.text.trim();
    final day = _returnsDayKey;
    setState(() {
      _returnsLoading = true;
      _returnsError = null;
    });
    final sales = <String, PosSale>{};
    for (final sale in [
      ..._sales,
      ...await widget.offlineStore.readOfflineSales()
    ]) {
      sales[sale.invoiceNumber ?? sale.receiptNumber] = sale;
    }
    String? error;
    List<PosExchange>? exchanges;
    try {
      var page = 1;
      while (mounted && request == _returnsRequest) {
        final result = await _adminApi.getPosSales(
            page: page, pageSize: 100, search: query, day: day);
        for (final sale in result.sales) {
          sales[sale.invoiceNumber ?? sale.receiptNumber] = sale;
        }
        if (page >= result.pageCount || result.sales.isEmpty) break;
        page++;
      }
      if (mounted && request == _returnsRequest) {
        exchanges = await _adminApi.getPosExchanges(search: query, day: day);
      }
    } catch (exception) {
      error =
          'Could not refresh server records. Showing available saved records. $exception';
    }
    if (!mounted || request != _returnsRequest) return;
    setState(() {
      _returnSales = sales.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _returnExchanges = exchanges;
      _returnsLoading = false;
      _returnsError = error;
    });
  }

  Widget _buildReturnsAndRefunds() {
    final query = _returnsSearch.text.trim().toLowerCase();
    bool matches(String text, DateTime date) {
      final nepal = date.toUtc().add(const Duration(hours: 5, minutes: 45));
      return (query.isEmpty || text.toLowerCase().contains(query)) &&
          (_returnsDay == null ||
              (nepal.year == _returnsDay!.year &&
                  nepal.month == _returnsDay!.month &&
                  nepal.day == _returnsDay!.day));
    }

    final eligibleSales = (_returnSales ?? _sales).where((sale) =>
        matches(
            '${sale.customerName ?? ''} ${sale.customerPhone ?? ''} ${sale.receiptNumber} ${sale.invoiceNumber ?? ''}',
            sale.createdAt) &&
        sale.status != 'CANCELLED' &&
        sale.paymentStatus == 'COMPLETED' &&
        sale.refundedAmount < sale.total);
    final exchanges = (_returnExchanges ?? _exchanges)
        .where((exchange) => matches(
            '${exchange.customerName} ${exchange.customerPhone} ${exchange.receiptNumber} ${exchange.invoiceNumber ?? ''}',
            exchange.requestedAt))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Returns & exchanges'),
        const SizedBox(height: 8),
        TextField(
            controller: _returnsSearch,
            decoration: const BillingInputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search customer name, phone or bill number'),
            onChanged: (_) {
              setState(() {});
              _returnsTimer?.cancel();
              _returnsTimer =
                  Timer(const Duration(milliseconds: 350), _loadReturns);
            }),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: BillingText(
                  _returnsDay == null ? 'All dates' : _returnsDayKey!),
              onPressed: () async {
                final selected = await showDatePicker(
                    context: context,
                    initialDate: _returnsDay ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)));
                if (selected != null && mounted) {
                  setState(() => _returnsDay = selected);
                  unawaited(_loadReturns());
                }
              }),
          if (_returnsDay != null || query.isNotEmpty)
            TextButton(
                onPressed: () {
                  _returnsSearch.clear();
                  setState(() => _returnsDay = null);
                  unawaited(_loadReturns());
                },
                child: const BillingText('Clear filters')),
          BillingIconButton(
              tooltip: 'Refresh returns',
              onPressed: _returnsLoading ? null : _loadReturns,
              icon: const Icon(Icons.refresh)),
        ]),
        if (_returnsLoading) const LinearProgressIndicator(),
        if (_returnsError != null)
          BillingText(_returnsError!, style: TextStyle(color: _muted)),
        if (_exchangeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MaterialBanner(
              content: BillingText(
                'Exchange services are unavailable on the connected backend. '
                'Update the backend and apply the pending POS exchange migration '
                'before using exchanges. $_exchangeError',
              ),
              actions: [
                TextButton(onPressed: _load, child: const BillingText('Retry')),
              ],
            ),
          ),
        if (!widget.isBillingStaff)
          ...exchanges
              .where((exchange) => exchange.status == 'REFUND_REQUESTED')
              .map(_exchangeReviewTile),
        if (eligibleSales.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BillingText(
              'Completed bills eligible for a return or exchange will appear here.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...eligibleSales.map(
            (sale) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz_rounded),
              title: BillingText(sale.invoiceNumber ?? sale.receiptNumber),
              subtitle: BillingText(
                  '${sale.customerName ?? 'Walk-in'} · ${sale.customerPhone ?? ''}\nOriginal bill ${_money(sale.total)}'),
              trailing: OutlinedButton(
                onPressed: _working ? null : () => _openExchange(sale),
                child: const BillingText('Start exchange'),
              ),
            ),
          ),
        if (exchanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeading('Exchange history'),
          ...exchanges.map(_exchangeHistoryTile),
        ],
      ],
    );
  }

  Widget _exchangeReviewTile(PosExchange exchange) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_rounded),
        title: BillingText('${exchange.receiptNumber} · refund review'),
        subtitle: BillingText(
          'Refund ${_money(-exchange.difference)} · '
          '${exchange.items.where((item) => item.type == 'RETURN').length} returned item(s)',
        ),
        trailing: Wrap(
          children: [
            BillingIconButton(
              tooltip: 'Reject exchange refund',
              onPressed: _working
                  ? null
                  : () => _resolveExchange(exchange, approve: false),
              icon: const Icon(Icons.close_rounded),
            ),
            BillingIconButton(
              tooltip: 'Approve refund',
              onPressed: _working
                  ? null
                  : () => _resolveExchange(exchange, approve: true),
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exchangeHistoryTile(PosExchange exchange) {
    final difference = exchange.difference;
    final amountLabel = difference > 0
        ? 'Collected ${_money(difference)}'
        : difference < 0
            ? 'Refund ${_money(-difference)}'
            : 'Even exchange';
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: ExpansionTile(
        leading: Icon(
          exchange.status == 'REFUND_REQUESTED'
              ? Icons.pending_actions_rounded
              : Icons.swap_horiz_rounded,
        ),
        title: BillingText('${exchange.receiptNumber} · $amountLabel'),
        subtitle: BillingText(
          '${exchange.status.replaceAll('_', ' ')} · '
          '${_dateTime(exchange.requestedAt)}',
        ),
        children: [
          for (final item in exchange.items)
            ProductDetailRow(
              photoName: item.productName,
              store: widget.offlineStore,
              name:
                  '${item.type == 'RETURN' ? 'Return' : 'Replacement'}: ${item.productName}',
              subtitle: item.weightGrams == null
                  ? 'Qty ${item.quantity}'
                  : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg',
              amount: _money(item.lineTotal),
            ),
        ],
      ),
    );
  }

  Future<void> _resolveExchange(
    PosExchange exchange, {
    required bool approve,
  }) async {
    String? refundMethod;
    if (approve) {
      refundMethod = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const BillingText('Approve exchange refund'),
          content: BillingText(
            'Approve ${_money(-exchange.difference)} for '
            '${exchange.receiptNumber}? The returned and replacement stock '
            'will be adjusted only after approval.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const BillingText('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'CASH'),
              child: const BillingText('Refund cash'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'DIGITAL'),
              child: const BillingText('Refund digital'),
            ),
          ],
        ),
      );
      if (refundMethod == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const BillingText('Reject exchange refund'),
          content: BillingText(
            'Reject the refund difference for ${exchange.receiptNumber}? '
            'The exchange will not change inventory.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const BillingText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const BillingText('Reject request'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _perform(
      () => _adminApi.resolvePosExchange(
        exchange.id,
        approve: approve,
        refundPaymentMethod: refundMethod,
      ),
    );
  }

  Widget _buildPayments() => _buildRefundRequests();

  Widget _buildPendingPayments() {
    final onlinePending = _pendingPaymentPage?.sales ?? const <PosSale>[];
    final pending = [...onlinePending, ..._localPendingSales]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final page = _pendingPaymentPage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Pending cash',
          actions: [
            if (_isWindowsOperatorMode)
              OutlinedButton.icon(
                onPressed: _syncingPendingCashExport
                    ? null
                    : () => _syncPendingCashExport(showMessage: true),
                icon: const Icon(Icons.table_view_outlined),
                label: const BillingText('Save Excel'),
              ),
            if (page != null)
              Chip(
                avatar: const Icon(Icons.account_balance_wallet_outlined),
                label: BillingText(
                  '${page.total + _localPendingSales.length} bill${(page.total + _localPendingSales.length) == 1 ? '' : 's'}',
                ),
              )
            else if (_localPendingSales.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.account_balance_wallet_outlined),
                label:
                    BillingText('${_localPendingSales.length} local bill(s)'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _pendingPaymentSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(pendingPage: 1),
                decoration: BillingInputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search customer, phone or POS code',
                  suffixIcon: BillingIconButton(
                    tooltip: 'Search pending payments',
                    onPressed: () => _load(pendingPage: 1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _selectPendingPaymentDay,
              icon: const Icon(Icons.calendar_month_outlined),
              label: BillingText(_pendingPaymentDayKey.isEmpty
                  ? 'All dates'
                  : _pendingPaymentDayKey),
            ),
            if (_pendingPaymentDayKey.isNotEmpty)
              BillingIconButton(
                tooltip: 'Clear payment date filter',
                onPressed: () {
                  setState(() => _pendingPaymentDayKey = '');
                  unawaited(_load(pendingPage: 1));
                },
                icon: const Icon(Icons.clear_rounded),
              ),
          ],
        ),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BillingText(
              'No customer balances are waiting for collection.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...pending.map((sale) {
            final paid = sale.paidAmount ?? 0;
            final outstanding = sale.outstandingAmount ??
                (sale.total - paid).clamp(0, sale.total);
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.pending_actions_outlined),
                ),
                title: BillingText(
                  sale.customerName?.trim().isNotEmpty == true
                      ? sale.customerName!
                      : 'Customer',
                ),
                subtitle: BillingText(
                  '${sale.customerPhone ?? 'No phone'} · ${sale.receiptNumber} · '
                  'Bill ${_money(sale.total)} · Paid ${_money(paid)} · '
                  'Due ${_money(outstanding)}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: _working || outstanding <= 0
                      ? null
                      : () => _markPaid(sale),
                  child: const BillingText('Record payment'),
                ),
                children: [
                  for (final item in sale.items)
                    ProductDetailRow(
                      productId: item.productId,
                      sku: item.sku,
                      store: widget.offlineStore,
                      name: item.productName,
                      subtitle: item.weightGrams == null
                          ? 'Qty ${item.quantity}'
                          : '${item.weightGrams} g',
                      amount: _money(item.lineTotal),
                    ),
                  if (sale.paymentCollections.isNotEmpty)
                    const Divider(height: 1),
                  for (final payment in sale.paymentCollections)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        ['DIGITAL', 'FONEPAY', 'ESEWA'].contains(payment.method)
                            ? Icons.phone_android_rounded
                            : Icons.payments_outlined,
                      ),
                      title: BillingText(
                        '${_money(payment.amount)} · '
                        '${_paymentLabel(payment.method)}',
                      ),
                      subtitle: BillingText(
                        '${_dateTime(payment.createdAt)}'
                        '${payment.note?.isNotEmpty == true ? ' · ${_paymentNoteLabel(payment.note!)}' : ''}',
                      ),
                    ),
                ],
              ),
            );
          }),
        if (page != null && page.pageCount > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _working || page.page <= 1
                    ? null
                    : () => _load(pendingPage: page.page - 1),
                child: const BillingText('Previous'),
              ),
              BillingText('Page ${page.page} of ${page.pageCount}'),
              TextButton(
                onPressed: _working || page.page >= page.pageCount
                    ? null
                    : () => _load(pendingPage: page.page + 1),
                child: const BillingText('Next'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _printerSettings(PosOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Receipt & printer settings'),
        if ((_postCommit?.pendingTasks ?? 0) > 0) ...[
          BillingText('Background tasks pending: ${_postCommit!.pendingTasks}'),
          BillingText(_postCommit!.lastError ?? ''),
          TextButton(
              onPressed: () => unawaited(_postCommit!.run()),
              child: const BillingText('Retry background tasks')),
        ],
        if (defaultTargetPlatform == TargetPlatform.windows)
          ListTile(
            title: BillingText(_printerName ?? 'Select receipt printer'),
            subtitle: const BillingText(
                'Choose Deli ES301 for direct receipt printing. Reprints use the same saved bill.'),
            trailing: FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const BillingText('Choose printer'),
                onPressed: () async {
                  try {
                    final printer = await ReceiptPrintService.choose(context);
                    if (mounted && printer != null) {
                      setState(() => _printerName = printer.name);
                    }
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              BillingText('Could not select printer: $error')));
                    }
                  }
                }),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.print_outlined),
            const SizedBox(width: 10),
            const Expanded(child: BillingText('Receipt paper width')),
            DropdownButton<int>(
              value: _paperWidthMm,
              onChanged: _working
                  ? null
                  : (value) {
                      if (value != null) unawaited(_setPaperWidth(value));
                    },
              items: const [
                DropdownMenuItem(value: 58, child: BillingText('58 mm')),
                DropdownMenuItem(value: 80, child: BillingText('80 mm')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const BillingText(
            'Choose the paper width used by your thermal printer. Receipt length adjusts automatically to the bill contents.'),
      ],
    );
  }

  Widget _buildHeldBills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Held bills',
          actions: [
            BillingText(
              '${_heldSales.length} waiting',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (_heldSales.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BillingText(
              'Bills you put on hold will be available here.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ..._heldSales.map(
            (held) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: BillingText(held.customerName?.isNotEmpty == true
                  ? held.customerName!
                  : 'Held bill'),
              subtitle: BillingText('${held.items.length} item lines'),
              trailing: Wrap(
                children: [
                  BillingIconButton(
                    tooltip: 'Discard held bill',
                    onPressed: () => _perform(
                      () => _adminApi.deletePosHeldSale(held.id),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _newBill(heldSale: held),
                    child: const BillingText('Resume'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _saleTile(PosSale sale) {
    final isLocal = sale.localPath != null;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(
              isLocal ? Icons.computer_outlined : Icons.receipt_long_outlined),
        ),
        title: BillingText(sale.invoiceNumber ?? sale.receiptNumber),
        subtitle: BillingText(
          '${_money(sale.total)} · ${sale.paymentStatus == 'PENDING' ? 'Due ${_money(sale.outstandingAmount ?? sale.total)}' : _paymentLabel(sale.paymentMethod)} · ${_dateTime(sale.createdAt)}',
        ),
        trailing: isLocal
            ? const Chip(label: BillingText('Local'))
            : sale.paymentStatus == 'PENDING'
                ? Wrap(
                    children: [
                      BillingIconButton(
                        tooltip: 'Record received payment',
                        onPressed: () => _markPaid(sale),
                        icon: const Icon(Icons.payments_outlined),
                      ),
                      if (!widget.isBillingStaff && (sale.paidAmount ?? 0) <= 0)
                        BillingIconButton(
                          tooltip: 'Cancel unpaid bill',
                          onPressed: () => _cancelSale(sale),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                    ],
                  )
                : sale.status == 'REFUNDED'
                    ? const Chip(label: BillingText('Refunded'))
                    : widget.isBillingStaff
                        ? const SizedBox.shrink()
                        : BillingIconButton(
                            tooltip: 'Request refund',
                            onPressed: sale.status == 'CANCELLED'
                                ? null
                                : () => _requestRefund(sale),
                            icon: const Icon(Icons.currency_exchange_rounded),
                          ),
        children: [
          ListTile(
            dense: true,
            title: const BillingText('Customer'),
            subtitle: BillingText(
              (sale.customerName?.trim().isNotEmpty ?? false) ||
                      (sale.customerPhone?.trim().isNotEmpty ?? false)
                  ? [sale.customerName, sale.customerPhone]
                      .where((value) => value?.trim().isNotEmpty ?? false)
                      .join(' · ')
                  : 'Walk-in customer',
            ),
          ),
          ListTile(
            dense: true,
            title: const BillingText('Invoice totals'),
            subtitle: BillingText(
              'Subtotal ${_money(sale.subtotal)}  ·  '
              'Discount ${_money(sale.discount)}  ·  '
              'VAT ${_money(sale.vatAmount)} (${sale.vatRate.toStringAsFixed(2)}%)',
            ),
            trailing: BillingText(
              'Total ${_money(sale.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final item in sale.items)
            ProductDetailRow(
              productId: item.productId,
              sku: item.sku,
              store: widget.offlineStore,
              name: item.productName,
              subtitle: item.weightGrams == null
                  ? 'Qty ${item.quantity} · ${item.sku}'
                  : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg · ${item.sku}',
              amount: _money(item.lineTotal),
            ),
          if (sale.refundedAmount > 0)
            ListTile(
              dense: true,
              title: const BillingText('Refunded'),
              trailing: BillingText(_money(sale.refundedAmount)),
            ),
          for (final payment in sale.paymentCollections)
            ListTile(
              dense: true,
              title: BillingText(
                '${_money(payment.amount)} · ${_paymentLabel(payment.method)}',
              ),
              subtitle: BillingText(_dateTime(payment.createdAt)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _printOrShareInvoice(sale),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const BillingText('Print or share invoice PDF'),
              ),
            ),
          ),
          if (isLocal && sale.localPath != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: const BillingText('Local invoice file'),
              subtitle: SelectableText(sale.localPath!),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceManagementToolbar() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _billHistorySearchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) =>
                    setState(() => _billHistorySearch = value),
                onSubmitted: (_) => _searchBillHistory(),
                decoration: BillingInputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search POS code, customer or phone',
                  isDense: true,
                  suffixIcon: BillingIconButton(
                    tooltip: 'Search invoices',
                    onPressed: _searchBillHistory,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectHistoryDay,
              icon: const Icon(Icons.calendar_month_outlined),
              label: BillingText(_billHistoryDayKey ?? 'All dates'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const BillingText('Refresh'),
            ),
            BillingText('Total: $_salesTotal',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Future<void> _printOrShareInvoice(PosSale sale) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _printManuallyVerifiedBill(sale);
        return;
      }
      final thermal = defaultTargetPlatform == TargetPlatform.windows;
      final bytes = thermal
          ? await PosReceiptService.createPdf(sale, paperWidthMm: _paperWidthMm)
          : await PosReceiptService.createInvoicePdf(sale);
      await BillPdfArchiveService.save(sale, bytes);
      if (!mounted) return;
      final filename = BillPdfArchiveService.fileName(sale);
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await Printing.layoutPdf(
          name: filename,
          format: thermal
              ? PosReceiptService.pageFormat(sale, paperWidthMm: _paperWidthMm)
              : PdfPageFormat.a4,
          dynamicLayout: !thermal,
          onLayout: (_) async => bytes,
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            'Could not prepare this invoice: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _exportSalesCsv() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final sales = <PosSale>[];
      var page = 1;
      var pageCount = 1;
      do {
        final result = await _adminApi.getPosSales(
          page: page,
          pageSize: 100,
          day: _billHistoryDayKey,
        );
        sales.addAll(result.sales);
        pageCount = result.pageCount;
        page++;
      } while (page <= pageCount && sales.isNotEmpty);

      final rows = <List<String>>[
        [
          'Receipt',
          'Date',
          'Customer',
          'Phone',
          'Sale status',
          'Payment status',
          'Payment method',
          'Subtotal',
          'Discount',
          'Total',
          'Paid',
          'Balance due',
          'Refunded',
          'Items',
        ],
        for (final sale in sales)
          [
            _csvCell(sale.receiptNumber, protectFormula: true),
            _csvCell(sale.createdAt.toLocal().toIso8601String()),
            _csvCell(sale.customerName ?? '', protectFormula: true),
            _csvCell(sale.customerPhone ?? '', protectFormula: true),
            _csvCell(sale.status),
            _csvCell(sale.paymentStatus),
            _csvCell(sale.paymentMethod),
            _csvCell(sale.subtotal.toStringAsFixed(2)),
            _csvCell(sale.discount.toStringAsFixed(2)),
            _csvCell(sale.total.toStringAsFixed(2)),
            _csvCell(_salePaidAmount(sale).toStringAsFixed(2)),
            _csvCell(_saleOutstandingAmount(sale).toStringAsFixed(2)),
            _csvCell(sale.refundedAmount.toStringAsFixed(2)),
            _csvCell(
              sale.items
                  .map((item) =>
                      '${item.productName} x ${item.weightGrams == null ? item.quantity : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg'}')
                  .join('; '),
              protectFormula: true,
            ),
          ],
      ];
      final csv = rows.map((row) => row.join(',')).join('\r\n');
      final dateSuffix = _billHistoryDayKey ?? 'all-days';
      final fileName = 'Ram-Prasad-Bills-$dateSuffix.csv';
      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        dialogTitle: 'Export bill history',
        allowedExtensions: const ['csv'],
      );
      if (!mounted || savedUri == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                BillingText('Exported ${sales.length} bills to $fileName')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            'Could not export bill history: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _csvCell(String value, {bool protectFormula = false}) {
    var safeValue = value;
    if (protectFormula && RegExp(r'^[=+\-@\t\r]').hasMatch(safeValue)) {
      safeValue = "'$safeValue";
    }
    return '"${safeValue.replaceAll('"', '""')}"';
  }

  double _salePaidAmount(PosSale sale) {
    final recordedPayments = sale.paymentCollections.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    return (sale.paidAmount ??
            (sale.paymentStatus == 'COMPLETED' ? sale.total : recordedPayments))
        .clamp(0, sale.total)
        .toDouble();
  }

  double _saleOutstandingAmount(PosSale sale) =>
      (sale.outstandingAmount ?? sale.total - _salePaidAmount(sale))
          .clamp(0, sale.total)
          .toDouble();

  Widget _buildInsights(PosOverview overview) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _insightCard(
            'Top-selling products',
            overview.topProducts.isEmpty
                ? const [BillingText('No sales recorded today.')]
                : overview.topProducts
                    .map((item) => _insightLine(item.name, '× ${item.sold}'))
                    .toList(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _insightCard(
            'Low-stock alerts',
            overview.lowStock.isEmpty
                ? const [BillingText('No low-stock products.')]
                : overview.lowStock
                    .take(6)
                    .map((item) => _insightLine(
                          item.name,
                          '${item.available} ${item.unitLabel}',
                        ))
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _insightCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BillingText(title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _insightLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: BillingText(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            BillingText(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _buildRefundRequests() {
    final requested =
        _refunds.where((item) => item.status == 'REQUESTED').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Refund requests',
          actions: [
            if (requested.isNotEmpty)
              Chip(label: BillingText('${requested.length} pending')),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _refundSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: BillingInputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search invoice, customer, phone or reason',
                  suffixIcon: BillingIconButton(
                    tooltip: 'Search refunds',
                    onPressed: _load,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _selectRefundDay,
              icon: const Icon(Icons.calendar_month_outlined),
              label: BillingText(
                  _refundDayKey.isEmpty ? 'All dates' : _refundDayKey),
            ),
            if (_refundDayKey.isNotEmpty)
              BillingIconButton(
                tooltip: 'Clear refund date filter',
                onPressed: () {
                  setState(() => _refundDayKey = '');
                  unawaited(_load());
                },
                icon: const Icon(Icons.clear_rounded),
              ),
          ],
        ),
        if (requested.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BillingText(
              'No refund requests need review.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...requested.map(
            (refund) => Card(
              child: ListTile(
                title: BillingText(
                    '${refund.receiptNumber} · ${_money(refund.amount)}'),
                subtitle: BillingText([
                  if (refund.customerName?.trim().isNotEmpty == true)
                    refund.customerName!.trim(),
                  if (refund.customerPhone?.trim().isNotEmpty == true)
                    refund.customerPhone!.trim(),
                  refund.reason,
                  'Requested by ${refund.requestedBy}',
                ].join(' · ')),
                trailing: Wrap(
                  children: [
                    BillingIconButton(
                      tooltip: 'Reject refund',
                      onPressed: _working
                          ? null
                          : () => _resolveRefund(refund, approve: false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    BillingIconButton(
                      tooltip: 'Approve refund',
                      onPressed: _working
                          ? null
                          : () => _resolveRefund(refund, approve: true),
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _resolveRefund(PosRefund refund, {required bool approve}) async {
    await _perform(
      () => _adminApi.resolvePosRefund(refund.id, approve: approve),
    );
  }

  Future<void> _markPaid(PosSale sale) async {
    final remaining = sale.outstandingAmount ??
        (sale.total - (sale.paidAmount ?? 0)).clamp(0, sale.total).toDouble();
    final amountController =
        TextEditingController(text: remaining.toStringAsFixed(2));
    final noteController = TextEditingController();
    var paymentMethod = 'CASH';
    String? validationError;
    final payment =
        await showDialog<({double amount, String method, String? note})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: BillingText('Receive payment · ${sale.receiptNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BillingText(
                  'Remaining balance ${_money(remaining)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const BillingInputDecoration(
                  labelText: 'Amount received',
                  prefixText: 'Rs ',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: paymentMethod,
                decoration:
                    const BillingInputDecoration(labelText: 'Received by'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: BillingText('Cash')),
                  DropdownMenuItem(
                    value: 'DIGITAL',
                    child: BillingText('Bank transfer (manual record)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => paymentMethod = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLength: 240,
                decoration: const BillingInputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              if (validationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: BillingText(
                    validationError!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const BillingText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null ||
                    !amount.isFinite ||
                    (amount * 100).round() < 1 ||
                    amount > remaining) {
                  setDialogState(() {
                    validationError =
                        'Enter an amount from Rs 0.01 up to ${_money(remaining)}.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, (
                  amount: amount,
                  method: paymentMethod,
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                ));
              },
              child: const BillingText('Save payment'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (payment == null) return;
    var paymentSaved = false;
    String? receiptWarning;
    await _perform(() async {
      if (sale.localPath != null && sale.id.startsWith('local-')) {
        final jsonFile = File(sale.localPath!);
        final decoded = await const LocalBillingStore().readJson(jsonFile);
        final newPaid = ((sale.paidAmount ?? 0) + payment.amount)
            .clamp(0, sale.total)
            .toDouble();
        final due = (sale.total - newPaid).clamp(0, sale.total).toDouble();
        final now = DateTime.now();
        final collections = [
          ...sale.paymentCollections,
          PosPaymentCollection(
            id: 'local-payment-${const Uuid().v4()}',
            amount: payment.amount,
            method: payment.method,
            note: payment.note,
            createdAt: now,
          ),
        ];
        decoded['paidAmount'] = newPaid;
        decoded['outstandingAmount'] = due;
        decoded['paymentStatus'] = due > 0 ? 'PENDING' : 'COMPLETED';
        decoded['paymentMethod'] = due > 0 ? 'PENDING' : payment.method;
        decoded['paymentCollections'] = collections
            .map((collection) => {
                  'id': collection.id,
                  'amount': collection.amount,
                  'method': collection.method,
                  'note': collection.note,
                  'createdAt': collection.createdAt.toIso8601String(),
                })
            .toList(growable: false);
        await const LocalBillingStore().updateLocalBill(jsonFile, decoded,
            expectedPaidAmount: sale.paidAmount ?? 0);
        final updatedSale = PosSale(
          id: sale.id,
          receiptNumber: sale.receiptNumber,
          invoiceNumber: sale.invoiceNumber,
          customerName: sale.customerName,
          customerPhone: sale.customerPhone,
          status: sale.status,
          paymentMethod: due > 0 ? 'PENDING' : payment.method,
          paymentStatus: due > 0 ? 'PENDING' : 'COMPLETED',
          subtotal: sale.subtotal,
          discount: sale.discount,
          vatRate: sale.vatRate,
          vatAmount: sale.vatAmount,
          total: sale.total,
          refundedAmount: sale.refundedAmount,
          createdAt: sale.createdAt,
          items: sale.items,
          paidAmount: newPaid,
          outstandingAmount: due,
          paymentCollections: collections,
          localPath: sale.localPath,
        );
        final basename = jsonFile.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.json$', caseSensitive: false),
          '',
        );
        try {
          final bytes = await PosReceiptService.createInvoicePdf(updatedSale);
          await File('${jsonFile.parent.path}/$basename.pdf').writeAsBytes(
            bytes,
            flush: true,
          );
          await BillPdfArchiveService.save(updatedSale, bytes);
        } catch (error) {
          receiptWarning =
              'Payment saved. Regenerate the invoice PDF from bill history: $error';
        }
      } else {
        await _recordPaymentWithRetryKey(sale,
            amount: payment.amount, method: payment.method, note: payment.note);
      }
      paymentSaved = true;
      return null;
    });
    if (paymentSaved) unawaited(StoreAudioService.playConfirmation());
    if (receiptWarning != null && mounted) _showMessage(receiptWarning!);
  }

  Future<void> _recordPaymentWithRetryKey(
    PosSale sale, {
    required double amount,
    required String method,
    String? note,
  }) async {
    final owner = context.read<AuthProvider>().currentUser?.id ?? '';
    final preferences = await SharedPreferences.getInstance();
    final key = 'pos_payment_attempt_${owner}_${sale.id}';
    final fingerprint = jsonEncode({
      'cents': (amount * 100).round(),
      'method': method,
      'note': note?.trim() ?? ''
    });
    final saved = preferences.getString(key);
    Map<String, dynamic>? attempt =
        saved == null ? null : jsonDecode(saved) as Map<String, dynamic>;
    if (attempt != null &&
        sale.paymentCollections.any((collection) =>
            collection.id ==
            'PPC-${attempt!['id'].toString().toUpperCase()}')) {
      await preferences.remove(key);
      attempt = null;
    }
    if (attempt != null && attempt['fingerprint'] != fingerprint) {
      throw StateError(
          'A previous payment response is unconfirmed. Refresh the bill and retry that same amount and method before recording a different payment.');
    }
    attempt ??= {'id': const Uuid().v4(), 'fingerprint': fingerprint};
    if (!await preferences.setString(key, jsonEncode(attempt))) {
      throw StateError(
          'Could not save the payment retry reference. No payment was sent.');
    }
    try {
      await _adminApi.recordPosPayment(sale.id,
          paymentMethod: method,
          amount: amount,
          note: note,
          idempotencyKey: attempt['id'] as String);
      await preferences.remove(key);
    } on ApiResponseException catch (error) {
      if ([400, 401, 403, 404, 409].contains(error.statusCode)) {
        await preferences.remove(key);
      }
      rethrow;
    }
  }

  String _paymentLabel(String method) => switch (method) {
        'DIGITAL' => 'Bank transfer',
        'FONEPAY' => 'Fonepay',
        'ESEWA' => 'eSewa',
        'PENDING' => 'Pending',
        _ => 'Cash',
      };

  Future<void> _cancelSale(PosSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const BillingText('Cancel unpaid bill?'),
        content: BillingText(
          'Cancel ${sale.receiptNumber} and return its items to available stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const BillingText('Keep bill'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const BillingText('Cancel bill'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(() => _adminApi.cancelPosSale(sale.id));
  }

  Future<void> _showDailyReport() async {
    final overview = _reportOverview ?? _overview;
    if (overview == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: BillingText('Billing report · ${overview.day}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _insightLine('Sales', _money(overview.totalSales)),
            _insightLine('Completed bills', '${overview.completedBills}'),
            _insightLine('Average bill', _money(overview.averageBillValue)),
            _insightLine('Cash received', _money(overview.cashSales)),
            _insightLine('Digital received', _money(overview.digitalSales)),
            _insightLine('Pending payment', _money(overview.pendingSales)),
            _insightLine('Refunds', _money(overview.refunds)),
            _insightLine('Cancelled bills', '${overview.cancelledBills}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const BillingText('Done'),
          ),
        ],
      ),
    );
  }

  String _money(double amount) =>
      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PosProductQuantityDialog extends StatefulWidget {
  const _PosProductQuantityDialog({
    required this.product,
    required this.isWeightProduct,
    this.initialQuantity = 1,
  });

  final PosProduct product;
  final bool isWeightProduct;
  final int initialQuantity;

  @override
  State<_PosProductQuantityDialog> createState() =>
      _PosProductQuantityDialogState();
}

class _PosProductQuantityDialogState extends State<_PosProductQuantityDialog> {
  late final TextEditingController _quantityController =
      TextEditingController(text: '${widget.initialQuantity}');

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity != null && quantity > 0) Navigator.pop(context, quantity);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          ProductThumbnail(imageUrl: widget.product.imageUrl ?? '', size: 56),
          const SizedBox(width: 12),
          Expanded(child: BillingText('Add ${widget.product.name}')),
        ]),
        content: TextField(
          controller: _quantityController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: BillingInputDecoration(
            labelText: widget.isWeightProduct ? 'Weight in grams' : 'Quantity',
            suffixText: widget.isWeightProduct ? 'g' : null,
          ),
          onSubmitted: (_) => _submit(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const BillingText('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submit(context),
            child: const BillingText('Add to bill'),
          ),
        ],
      );
}

class PosBillDialog extends StatefulWidget {
  const PosBillDialog({
    super.key,
    required this.api,
    required this.onScan,
    required this.onNewBill,
    this.offlineStore = const OfflinePosStore(),
    this.refreshCatalogOnOpen = true,
    required this.operatorId,
    required this.allowOfflineSync,
    this.allowPriceEditing = true,
    this.localSync,
    this.printSale,
    this.paperWidthMm = 80,
    this.heldSale,
    this.scannedProduct,
    this.loadLocalCustomers,
    this.requireRoomSelection = false,
  });

  final AdminApiService api;
  final PosHeldSale? heldSale;
  final PosProduct? scannedProduct;
  final Future<PosProduct?> Function() onScan;
  final VoidCallback onNewBill;
  final String operatorId;
  final bool allowOfflineSync;
  final bool allowPriceEditing;
  final LocalBillingSync? localSync;
  final Future<bool> Function(PosSale)? printSale;
  final int paperWidthMm;
  final OfflinePosStore offlineStore;
  final bool refreshCatalogOnOpen;
  final Future<List<AdminCustomer>> Function()? loadLocalCustomers;

  /// When false, billing consumes aggregate stock and does not ask the
  /// cashier to choose a source room. Inventory room tracking remains
  /// available to stores that explicitly enable it.
  final bool requireRoomSelection;

  @override
  State<PosBillDialog> createState() => _PosBillDialogState();
}

class _PosBillDialogState extends State<PosBillDialog> {
  List<RoomPick>? _roomPicks;
  final _assignedRoomProducts = <String>{};
  final _roomLabels = <String, String>{};
  bool _choosingRooms = false;
  bool _roomSelectionNeedsRefresh = false;
  OfflinePosStore get _offlinePosStore => widget.offlineStore;
  final _barcodeQueue = OrderedWorkQueue();
  final _additionQueue = OrderedWorkQueue();
  final String _idempotencyKey = const Uuid().v4();
  Future<List<AdminCustomer>>? _localBillingCustomers;
  Future<List<AdminCustomer>> _readLocalBillingCustomers() =>
      _localBillingCustomers ??= widget.loadLocalCustomers?.call() ??
          BillingCustomerService.readLocal(widget.offlineStore);
  final _search = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _vatRate = TextEditingController(text: '0');
  final _paidNow = TextEditingController(text: '0');
  final _searchFocus = FocusNode();
  Timer? _searchTimer;
  Timer? _offlineSyncTimer;
  List<PosProduct> _matches = const [];
  List<PosProduct> _catalogIndex = const [];
  final List<_PosCartLine> _cart = [];
  final _cartMembership = ValueNotifier<int>(0);
  final _cartTotals = ValueNotifier<int>(0);

  void _cartChanged({bool membership = false}) {
    if (membership) _cartMembership.value++;
    _cartTotals.value++;
  }

  bool _searching = false;
  bool _saving = false;
  bool _checkoutInProgress = false;
  bool _discountIsPercent = false;
  bool _saveOnThisComputer = false;
  AdminCustomer? _selectedCustomer;
  Timer? _customerSearchTimer;
  int _customerSearchRequest = 0;
  int _productSearchRequest = 0;
  String _paymentMethod = 'CASH';
  String _paidNowMethod = 'CASH';
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.localSync?.addListener(_onLocalSyncChanged);
    final openWatch = Stopwatch()..start();
    final held = widget.heldSale;
    if (held != null) {
      _customerName.text = held.customerName ?? '';
      _customerPhone.text = held.customerPhone ?? '';
      for (final item in held.items) {
        _cart.add(_PosCartLine(
          PosProduct(
            id: item['productId'] as String,
            name: item['productName'] as String,
            sku: item['sku'] as String,
            barcode: null,
            price:
                ((item['cataloguePrice'] ?? item['price']) as num).toDouble(),
            unitLabel: item['unitLabel'] as String,
            available: (item['productId'] as String).startsWith('manual-')
                ? 100000
                : 0,
          ),
          quantity: (item['quantity'] as num).toInt(),
          weightGrams: (item['weightGrams'] as num?)?.toInt(),
        )..setPrice((item['price'] as num).toDouble()));
      }
    }
    final scanned = widget.scannedProduct;
    if (scanned != null) _addProduct(scanned);
    if (held != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_additionQueue.run(() async {
          final products = {
            for (final line in _cart) line.product.id: line.product
          };
          for (final product in products.values) {
            final required = _cart
                .where((line) => line.product.id == product.id)
                .fold<int>(0,
                    (sum, line) => sum + (line.weightGrams ?? line.quantity));
            if (!await _chooseProductRooms(product, required)) break;
          }
        }));
      });
    }
    unawaited(_searchProducts(''));
    if (widget.refreshCatalogOnOpen) unawaited(_refreshOfflineCatalog());
    _offlineSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_retryPendingProductSync());
    });
    if (defaultTargetPlatform == TargetPlatform.windows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint(
              'PosBillDialog open -> ready after ${openWatch.elapsedMilliseconds}ms');
          _searchFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.localSync?.removeListener(_onLocalSyncChanged);
    _barcodeQueue.close();
    _additionQueue.close();
    _cartMembership.dispose();
    _cartTotals.dispose();
    _searchTimer?.cancel();
    _customerSearchTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _search.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _discount.dispose();
    _vatRate.dispose();
    _paidNow.dispose();
    _searchFocus.dispose();
    for (final line in _cart) {
      line.dispose();
    }
    super.dispose();
  }

  void _onLocalSyncChanged() {
    final sync = widget.localSync;
    if (mounted && sync != null && !sync.running && sync.online == true) {
      unawaited(_searchProducts(_search.text.trim()));
    }
  }

  void _customerDetailsChanged({required bool byName}) {
    ++_customerSearchRequest;
    if (_selectedCustomer != null) {
      if (byName) {
        _customerPhone.clear();
      } else {
        _customerName.clear();
      }
    }
    setState(() => _selectedCustomer = null);
    _customerSearchTimer?.cancel();
    _customerSearchTimer = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_lookupRegisteredCustomer(
            _customerName.text, _customerPhone.text,
            byName: byName)));
  }

  Future<void> _lookupRegisteredCustomer(String name, String phone,
      {bool byName = false}) async {
    final requestId = ++_customerSearchRequest;
    final query =
        !byName && phone.trim().isNotEmpty ? phone.trim() : name.trim();
    if (query.trim().isEmpty || (!byName && query.length < 3)) return;
    final normalizedPhone = BillingCustomerService.phoneKey(phone);
    final local = await _readLocalBillingCustomers();
    if (!mounted || requestId != _customerSearchRequest) return;
    final localMatch = BillingCustomerService.findExact(local,
        name: name, phone: normalizedPhone, byName: byName);
    if (localMatch != null) {
      setState(() {
        _selectedCustomer = localMatch;
        _customerName.text = localMatch.name;
        _customerPhone.text = localMatch.phone;
      });
      return;
    }
  }

  Future<void> _selectRegisteredCustomer() async {
    _customerSearchTimer?.cancel();
    ++_customerSearchRequest;
    final searchController = TextEditingController();
    var customers = <AdminCustomer>[];
    var loading = true;
    var initialSearchStarted = false;
    var searchVersion = 0;
    final localCustomersFuture = _readLocalBillingCustomers();
    String? loadError;
    final selected = await showDialog<AdminCustomer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> runSearch(String query) async {
            if (!dialogContext.mounted) return;
            final version = ++searchVersion;
            setDialogState(() {
              loading = true;
              loadError = null;
            });
            final local = await localCustomersFuture;
            if (!dialogContext.mounted || version != searchVersion) return;
            final text = query.trim().toLowerCase(),
                phone = BillingCustomerService.phoneKey(query);
            final localMatches = local
                .where((customer) =>
                    text.isEmpty ||
                    customer.name.toLowerCase().contains(text) ||
                    (phone.isNotEmpty &&
                        BillingCustomerService.phoneKey(customer.phone)
                            .contains(phone)))
                .toList();
            setDialogState(() {
              customers = localMatches;
              loading = false;
              loadError = null;
            });
          }

          if (!initialSearchStarted) {
            initialSearchStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) unawaited(runSearch(''));
            });
          }
          return AlertDialog(
            title: const BillingText('Select customer'),
            content: SizedBox(
              width: 540,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const BillingInputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search name or phone',
                    ),
                    onChanged: (value) => unawaited(runSearch(value)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : loadError != null
                            ? Center(child: BillingText(loadError!))
                            : customers.isEmpty
                                ? const Center(
                                    child: BillingText(
                                        'No saved customers found.'),
                                  )
                                : ListView.builder(
                                    itemCount: customers.length,
                                    itemBuilder: (context, index) {
                                      final customer = customers[index];
                                      return ListTile(
                                        leading:
                                            const Icon(Icons.person_outline),
                                        title: BillingText(customer.name),
                                        subtitle: BillingText(
                                          customer.id
                                                  .startsWith('local-customer-')
                                              ? '${customer.phone} · Saved on this computer'
                                              : customer.phone,
                                        ),
                                        onTap: () => Navigator.pop(
                                          dialogContext,
                                          customer,
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const BillingText('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCustomer = selected;
      _customerName.text = selected.name;
      _customerPhone.text = selected.phone;
    });
  }

  bool _isWeightProduct(PosProduct product) =>
      StockSummary.isLooseWeight(product);

  bool _isManualProduct(PosProduct product) => product.id.startsWith('manual-');

  Future<void> _addManualItem() async {
    if (_saving || _choosingRooms) return;
    final name = TextEditingController();
    final price = TextEditingController();
    final quantity = TextEditingController(text: '1');
    String? error;
    final item = await showDialog<PosProduct>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const BillingText('Add manual item'),
                scrollable: true,
                content: SizedBox(
                    width: 360,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          maxLength: 180,
                          decoration: const InputDecoration(
                              labelText: 'Name (optional)')),
                      TextField(
                          controller: price,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Unit price (NPR)')),
                      TextField(
                          controller: quantity,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity')),
                      if (error != null)
                        BillingText(error!,
                            style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      const BillingText(
                          'Manual items do not change inventory stock.'),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const BillingText('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final rate = double.tryParse(price.text.trim());
                        final count = int.tryParse(quantity.text.trim());
                        if (rate == null ||
                            !rate.isFinite ||
                            rate <= 0 ||
                            rate > 9999999 ||
                            (rate * 100 - (rate * 100).round()).abs() >
                                .000001 ||
                            count == null ||
                            count < 1 ||
                            count > 100000) {
                          update(() => error =
                              'Enter a positive price (up to 2 decimals) and quantity from 1 to 100000.');
                          return;
                        }
                        final id = 'manual-${const Uuid().v4()}';
                        Navigator.pop(
                            dialogContext,
                            PosProduct(
                                id: id,
                                name: name.text.trim().isEmpty
                                    ? 'Miscellaneous item'
                                    : name.text.trim(),
                                sku: id,
                                barcode: null,
                                price: rate,
                                unitLabel: '1 pc',
                                available: 100000));
                      },
                      child: const BillingText('Add')),
                ],
              )),
    );
    final count = int.tryParse(quantity.text.trim()) ?? 1;
    name.dispose();
    price.dispose();
    quantity.dispose();
    if (item == null || !mounted || _saving) return;
    _cart.add(_PosCartLine(item, quantity: count));
    _cartChanged(membership: true);
    _searchFocus.requestFocus();
  }

  double get _subtotal => _cart.fold<double>(
        0,
        (sum, item) =>
            sum +
            _roundBillMoney(item.unitPrice *
                (item.weightGrams == null
                    ? item.quantity
                    : item.weightGrams! / 1000)),
      );

  double get _total {
    final discount = _discountAmount;
    final vatRate = double.tryParse(_vatRate.text.trim()) ?? 0;
    final taxableAmount = (_subtotal - discount).clamp(0, double.infinity);
    return _roundBillMoney(
        taxableAmount + _roundBillMoney(taxableAmount * vatRate / 100));
  }

  double get _discountAmount {
    final value = double.tryParse(_discount.text.trim()) ?? 0;
    return _roundBillMoney(
        _discountIsPercent ? _subtotal * value / 100 : value);
  }

  double get _vatAmount {
    final discount = _discountAmount;
    final rate = double.tryParse(_vatRate.text.trim()) ?? 0;
    final taxable = (_subtotal - discount).clamp(0, double.infinity);
    return _roundBillMoney(taxable * rate / 100);
  }

  Future<PosSale> _createLocalSale({
    required double discount,
    required double vatRate,
    bool queueForSync = false,
    ManualFonepayVerification? manualVerification,
  }) async {
    if (!widget.allowOfflineSync) {
      throw StateError(
          'Offline checkout requires an authorized Windows administrator session.');
    }
    if (queueForSync &&
        (!widget.allowOfflineSync ||
            _paymentMethod == 'DIGITAL' ||
            (_paymentMethod == 'PENDING' && _paidNowMethod == 'DIGITAL'))) {
      throw StateError(
          'Offline server-bound billing supports administrator cash bills only. Reconnect to record a digital payment.');
    }
    final now = DateTime.now();
    final localStore = _offlinePosStore.billingStore;
    final invoiceNumber = localStore.invoiceNumber(_idempotencyKey, now);
    final vatAmount = _roundBillMoney((_subtotal - discount) * vatRate / 100);
    final total = _roundBillMoney(_subtotal - discount + vatAmount);
    final paidNow = _paymentMethod == 'PENDING'
        ? _roundBillMoney(double.tryParse(_paidNow.text.trim()) ?? 0)
            .clamp(0, total)
            .toDouble()
        : total;
    final isPending = paidNow < total;
    final sale = PosSale(
      id: 'local-$invoiceNumber',
      receiptNumber: invoiceNumber,
      invoiceNumber: invoiceNumber,
      customerName:
          _customerName.text.trim().isEmpty ? null : _customerName.text.trim(),
      customerPhone: _customerPhone.text.trim().isEmpty
          ? null
          : _customerPhone.text.trim(),
      status: 'COMPLETED',
      paymentMethod: isPending
          ? 'PENDING'
          : (_paymentMethod == 'PENDING' ? _paidNowMethod : _paymentMethod),
      paymentStatus: isPending ? 'PENDING' : 'COMPLETED',
      subtotal: _subtotal,
      discount: discount,
      vatRate: vatRate,
      vatAmount: vatAmount,
      total: total,
      refundedAmount: 0,
      createdAt: now,
      paidAmount: paidNow,
      outstandingAmount: (total - paidNow).clamp(0, total).toDouble(),
      paymentCollections: paidNow <= 0
          ? const []
          : [
              PosPaymentCollection(
                id: 'local-payment-$invoiceNumber',
                amount: paidNow,
                method: _paymentMethod == 'PENDING'
                    ? _paidNowMethod
                    : _paymentMethod,
                note: manualVerification?.toNote(total),
                createdAt: now,
              ),
            ],
      items: [
        for (final line in _cart)
          PosSaleItem(
            id: '$invoiceNumber-${line.product.id}',
            productId: line.product.id,
            productName: line.product.name,
            sku: line.product.sku,
            quantity: line.quantity,
            weightGrams: line.weightGrams,
            unitPrice: line.unitPrice,
            lineTotal: _roundBillMoney(line.unitPrice *
                (line.weightGrams == null
                    ? line.quantity
                    : line.weightGrams! / 1000)),
          ),
      ],
    );
    final directoryPath = localStore.rootPath;
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    final dataFile = await PosTiming.measure(
        'bill_saving',
        () => localStore.saveBill(
              requestId: _idempotencyKey,
              ownerId: widget.operatorId,
              queueForSync: queueForSync,
              validate: () => PosTiming.measure('stock_validation', () async {
                final snapshot =
                    await RoomInventoryService(widget.api, _offlinePosStore)
                        .load(offline: true);
                if (widget.requireRoomSelection) {
                  snapshot.validatePicks(_roomPicks ?? const [], {
                    for (final line
                        in _cart.where((l) => !_isManualProduct(l.product)))
                      line.product.id: _cart
                          .where((item) => item.product.id == line.product.id)
                          .fold<int>(
                              0,
                              (sum, item) =>
                                  sum + (item.weightGrams ?? item.quantity))
                  });
                }
                final catalogue =
                    await _offlinePosStore.readCatalog(freshStock: true);
                final available = {
                  for (final product in catalogue) product.id: product.available
                };
                final unlimited = {
                  for (final product in catalogue)
                    product.id: product.isUnlimited
                };
                final quantities = <String, int>{};
                for (final line in _cart) {
                  if (_isManualProduct(line.product)) continue;
                  quantities[line.product.id] =
                      (quantities[line.product.id] ?? 0) +
                          (line.weightGrams ?? line.quantity);
                }
                for (final entry in quantities.entries) {
                  if (unlimited[entry.key] == true) continue;
                  if (entry.value > (available[entry.key] ?? 0)) {
                    throw StateError(
                        'This bill exceeds the locally estimated stock. Review quantities before saving.');
                  }
                }
              }),
              uploadPayload: {
                if (_roomPicks != null)
                  'roomPicks':
                      _roomPicks!.map((pick) => pick.toJson()).toList(),
                'idempotencyKey': _idempotencyKey,
                'items': _requestItems(),
                if (_priceChanges.isNotEmpty)
                  'cataloguePriceChanges': _priceChanges,
                'discount': discount,
                'vatRate': vatRate,
                'paymentMethod': _paymentMethod,
                if (_paymentMethod == 'PENDING') ...{
                  'paidAmount': paidNow,
                  'paidNowMethod': _paidNowMethod,
                },
                'customerName': sale.customerName,
                'customerPhone': sale.customerPhone,
                if (_selectedCustomer != null &&
                    !_selectedCustomer!.id.startsWith('local-customer-'))
                  'customerId': _selectedCustomer!.id,
                if (widget.heldSale != null) 'heldSaleId': widget.heldSale!.id,
                'offlineSale': {
                  'invoiceNumber': invoiceNumber,
                  'occurredAt': now.toUtc().toIso8601String(),
                  'expectedTotal': total,
                  'unitPrices': {
                    for (final item in sale.items)
                      item.productId!: item.unitPrice
                  },
                },
              },
              record: {
                ...BillingPostCommit.tasks(sale, widget.paperWidthMm,
                    customerId: _selectedCustomer != null &&
                            !_selectedCustomer!.id.startsWith('local-customer-')
                        ? _selectedCustomer!.id
                        : null),
                if (_priceChanges.isNotEmpty)
                  'cataloguePriceChanges': _priceChanges,
                if (_roomPicks != null)
                  'roomPicks':
                      _roomPicks!.map((pick) => pick.toJson()).toList(),
                if (_roomPicks != null && !queueForSync)
                  'roomStockSyncState': 'pending',
                'invoiceNumber': invoiceNumber,
                'date': now.toIso8601String(),
                'customerName': sale.customerName,
                'customerPhone': sale.customerPhone,
                'paymentMethod': sale.paymentMethod,
                'paymentStatus': sale.paymentStatus,
                'paidAmount': sale.paidAmount,
                'outstandingAmount': sale.outstandingAmount,
                'paymentCollections': sale.paymentCollections
                    .map((payment) => {
                          'id': payment.id,
                          'amount': payment.amount,
                          'method': payment.method,
                          'note': payment.note,
                          'createdAt': payment.createdAt.toIso8601String(),
                        })
                    .toList(growable: false),
                'subtotal': _subtotal,
                'discount': discount,
                'vatRate': vatRate,
                'vatAmount': vatAmount,
                'total': total,
                'status': sale.status,
                'items': sale.items
                    .map((item) => {
                          'productId': item.productId,
                          'name': item.productName,
                          'sku': item.sku,
                          'quantity': item.quantity,
                          'weightGrams': item.weightGrams,
                          'unitPrice': item.unitPrice,
                          'amount': item.lineTotal,
                        })
                    .toList(growable: false),
              },
            ));
    return PosSale(
      id: sale.id,
      receiptNumber: sale.receiptNumber,
      invoiceNumber: sale.invoiceNumber,
      customerName: sale.customerName,
      customerPhone: sale.customerPhone,
      status: sale.status,
      paymentMethod: sale.paymentMethod,
      paymentStatus: sale.paymentStatus,
      subtotal: sale.subtotal,
      discount: sale.discount,
      vatRate: sale.vatRate,
      vatAmount: sale.vatAmount,
      total: sale.total,
      refundedAmount: sale.refundedAmount,
      createdAt: sale.createdAt,
      items: sale.items,
      paidAmount: sale.paidAmount,
      outstandingAmount: sale.outstandingAmount,
      paymentCollections: sale.paymentCollections,
      localPath: dataFile.path,
      autoPrintAllowed: manualVerification == null ||
          await localStore.claimInitialPrint(dataFile),
    );
  }

  Future<void> _searchProducts(String query) async {
    final requestId = ++_productSearchRequest;
    final totalWatch = Stopwatch()..start();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final localWatch = Stopwatch()..start();
      _catalogIndex = await _offlinePosStore.searchCatalog('');
      final normalized = query.trim().toLowerCase();
      final cached = _catalogIndex
          .where((product) =>
              normalized.isEmpty ||
              product.name.toLowerCase().contains(normalized) ||
              product.sku.toLowerCase().contains(normalized) ||
              (product.barcode ?? '').toLowerCase().contains(normalized))
          // Keep the complete imported catalogue visible when the query is
          // empty.  The previous cap hid products from the billing grid.
          .take(500)
          .toList(growable: false);
      debugPrint(
          'Pos billing: local search query="$query" completed in ${localWatch.elapsedMilliseconds}ms, results=${cached.length}');
      if (!mounted || requestId != _productSearchRequest) return;
      setState(() {
        _matches = cached;
        _searching = false;
      });
      debugPrint(
          'Pos billing: final product render query="$query" total=${totalWatch.elapsedMilliseconds}ms, visible=${_matches.length}');
    } catch (error) {
      final cachedProducts = await _offlinePosStore.searchCatalog(query);
      if (mounted && requestId == _productSearchRequest) {
        setState(() {
          _matches = cachedProducts;
          _error = cachedProducts.isNotEmpty
              ? null
              : 'No offline catalog is saved on this computer yet. Connect to the store once to load products for offline billing.';
          _searching = false;
        });
      }
      debugPrint(
          'Pos billing: offline fallback query="$query" total=${totalWatch.elapsedMilliseconds}ms, error=$error');
    }
  }

  Future<void> _refreshOfflineCatalog({bool force = false}) async {
    try {
      final refreshed = await _offlinePosStore.refreshCatalogIfNeeded(() async {
        // A failed queue upload must not prevent refreshing the server catalog.
        try {
          await widget.api.syncPendingOfflineProducts();
        } catch (_) {
          // Keep queued items locally and continue with any available catalog API.
        }
        final products = await widget.api.getAllProducts(sort: 'name_asc');
        List<AdminWholesaleItem> wholesaleItems = const [];
        var usedCachedWholesale = false;
        try {
          wholesaleItems = await widget.api.getAllWholesaleItems();
        } catch (_) {
          usedCachedWholesale = true;
        }
        final cachedWholesale = usedCachedWholesale
            ? (await _offlinePosStore.readCatalogBaseline())
                .where((product) => product.id.startsWith('wholesale-'))
                .toList(growable: false)
            : const <PosProduct>[];
        final catalog = <PosProduct>[
          ...products
              .where((product) => product.isActive)
              .map((product) => PosProduct(
                    id: product.id,
                    name: product.name,
                    sku: product.sku,
                    barcode: product.barcode,
                    price: product.price,
                    unitLabel: product.unitLabel,
                    available: product.posStockUnits,
                    isUnlimited: product.isUnlimited,
                    imageUrl: product.imageUrl,
                  )),
          if (usedCachedWholesale) ...cachedWholesale,
          if (!usedCachedWholesale)
            ...wholesaleItems.where((item) => item.isActive).map(
                  (item) => PosProduct(
                    id: 'wholesale-${item.id}',
                    name: item.name,
                    sku: item.sku,
                    barcode: null,
                    price: item.price,
                    unitLabel: item.unitLabel,
                    available: item.stock,
                    imageUrl: item.imageUrl,
                  ),
                ),
        ];
        return catalog;
      }, force: force);
      if (mounted &&
          refreshed &&
          _barcodeQueue.pending == 0 &&
          _additionQueue.pending == 0) {
        await _searchProducts(_search.text.trim());
      }
      final pending = await _offlinePosStore.readPendingProducts();
      final conflictCount =
          pending.where((entry) => entry['syncError'] is String).length;
      if (mounted && conflictCount > 0) {
        setState(() {
          _error =
              '$conflictCount offline product(s) match existing server codes but have different details or stock. They remain on this computer for review.';
        });
      }
    } catch (_) {
      // Keep the last successful catalog snapshot available while offline.
    }
  }

  Future<void> _retryPendingProductSync() async {
    if (!mounted) return;
    final pending = await _offlinePosStore.readPendingProducts();
    if (pending.isEmpty) return;
    await _refreshOfflineCatalog(force: true);
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    ++_productSearchRequest; // Invalidate immediately, including debounce time.
    _searchTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(_searchProducts(value.trim()));
    });
  }

  Future<void> _submitBarcode(String value) async {
    if (_saving || !mounted || value.trim().isEmpty) return;
    _searchTimer?.cancel();
    ++_productSearchRequest;
    try {
      await _barcodeQueue.run(() => _processBarcode(value));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _processBarcode(String value) async {
    if (!mounted) return;
    final barcode = value.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final normalized = barcode.toLowerCase();
      final cached = _catalogIndex.isNotEmpty
          ? _catalogIndex
          : await _offlinePosStore.searchCatalog('');
      final exact = cached.where((product) =>
          product.barcode?.toLowerCase() == normalized ||
          product.sku.toLowerCase() == normalized ||
          product.id.toLowerCase() == normalized);
      final candidate = exact.firstOrNull ??
          cached
              .where((product) =>
                  product.name.toLowerCase().contains(normalized) ||
                  product.sku.toLowerCase().contains(normalized) ||
                  (product.barcode?.toLowerCase().contains(normalized) ??
                      false))
              .firstOrNull;
      if (!mounted) return;
      if (candidate == null) {
        setState(() {
          _matches = const [];
          _searching = false;
          _error = 'No matching offline product for "$barcode".';
        });
        return;
      }
      await _addProduct(candidate);
      if (!mounted) return;
      setState(() {
        _matches = cached.take(500).toList(growable: false);
        _searching = false;
      });
      _search.clear();
      _searchFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _searching = false;
      });
    }
  }

  Future<bool> _addProduct(PosProduct product) async {
    if (_saving || !mounted) return false;
    try {
      return await _additionQueue.run(() => _promptAndAddProduct(product));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    }
  }

  Future<bool> _promptAndAddProduct(PosProduct product) async {
    if (!mounted || _saving) return false;
    final existingProduct =
        _cart.where((line) => _sameProduct(line.product, product)).firstOrNull;
    if (existingProduct != null) product = existingProduct.product;
    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _PosProductQuantityDialog(
        product: product,
        isWeightProduct: _isWeightProduct(product),
      ),
    );
    if (quantity == null || !mounted) return false;
    final required = _cart
        .where((line) => line.product.id == product.id)
        .fold<int>(
            quantity, (sum, line) => sum + (line.weightGrams ?? line.quantity));
    if (!await _chooseProductRooms(product, required)) return false;
    if (!mounted) return false;
    if (_isWeightProduct(product)) {
      _cart.add(_PosCartLine(product, weightGrams: quantity)
        ..setPrice(existingProduct?.unitPrice ?? product.price));
      _cartChanged(membership: true);
      return true;
    }
    final existing = _cart.where((item) =>
        item.weightGrams == null && _sameProduct(item.product, product));
    if (existing.isNotEmpty) {
      existing.first.setQuantity(existing.first.quantity + quantity);
      _cartChanged();
    } else {
      _cart.add(_PosCartLine(product, quantity: quantity));
      _cartChanged(membership: true);
    }
    return true;
  }

  Future<bool> _chooseProductRooms(PosProduct product, int required) async {
    if (!mounted) return false;
    if (_isManualProduct(product)) return true;
    if (!widget.requireRoomSelection) {
      _roomPicks = [
        ...?_roomPicks?.where((pick) => pick.productId != product.id),
      ];
      _assignedRoomProducts.remove(product.id);
      _roomSelectionNeedsRefresh = false;
      return true;
    }
    if (product.isUnlimited) {
      _roomPicks = [
        ...?_roomPicks?.where((pick) => pick.productId != product.id),
      ];
      _assignedRoomProducts.remove(product.id);
      return true;
    }
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
      _roomPicks = [
        ...?_roomPicks?.where((pick) => pick.productId != product.id),
        RoomPick(productId: product.id, roomId: null, quantity: required),
      ];
      _roomSelectionNeedsRefresh = false;
      return true;
    }
    setState(() {
      _choosingRooms = true;
      _error = null;
    });
    try {
      final roomService = RoomInventoryService(widget.api, _offlinePosStore);
      final snapshot =
          await roomService.loadLocalIfAvailable(productIds: [product.id]) ??
              await roomService.load(productIds: [product.id]);
      if (!mounted) return false;
      final assigned =
          snapshot.stocks[product.id]?.values.any((n) => n > 0) ?? false;
      _roomLabels
          .addEntries(snapshot.rooms.map((r) => MapEntry(r.id, r.label)));
      if (assigned) _assignedRoomProducts.add(product.id);
      List<RoomPick>? picks;
      if (assigned) {
        picks = await showDialog<List<RoomPick>>(
            context: context,
            barrierDismissible: false,
            builder: (_) => RoomPickDialog(
                snapshot: snapshot,
                products: [product],
                requiredQuantities: {product.id: required},
                initialPicks: _roomPicks
                        ?.where((p) => p.productId == product.id)
                        .toList() ??
                    const []));
        if (picks == null || !mounted) return false;
      } else {
        if (required >
            (snapshot.totals[product.id]?.available ?? product.available)) {
          throw StateError('Not enough available stock for this quantity.');
        }
        picks = [
          RoomPick(productId: product.id, roomId: null, quantity: required)
        ];
      }
      _roomPicks = [
        ...?_roomPicks?.where((p) => p.productId != product.id),
        ...picks
      ];
      if (assigned) {
        _assignedRoomProducts.add(product.id);
      } else {
        _assignedRoomProducts.remove(product.id);
      }
      _roomSelectionNeedsRefresh = false;
      return true;
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
      return false;
    } finally {
      if (mounted) setState(() => _choosingRooms = false);
    }
  }

  void _trimRoomPicks(String productId) {
    var left = _cart
        .where((line) => line.product.id == productId)
        .fold<int>(0, (sum, line) => sum + (line.weightGrams ?? line.quantity));
    final retained = <RoomPick>[];
    for (final pick in _roomPicks ?? <RoomPick>[]) {
      if (pick.productId != productId) {
        retained.add(pick);
        continue;
      }
      final take = pick.quantity.clamp(0, left);
      if (take > 0) {
        retained.add(RoomPick(
            productId: productId, roomId: pick.roomId, quantity: take));
      }
      left -= take;
    }
    _roomPicks = retained;
    if (!_cart.any((line) => line.product.id == productId)) {
      _assignedRoomProducts.remove(productId);
    }
  }

  Future<void> _changeLineQuantity(_PosCartLine line, int quantity,
      {int? delta}) async {
    if (_saving || _choosingRooms || quantity <= 0) return;
    await _additionQueue.run(() async {
      if (!mounted || !_cart.contains(line)) return;
      if (delta != null) quantity = line.quantity + delta;
      if (quantity <= 0) {
        _removeCartLine(line);
        return;
      }
      final required = _cart
          .where(
              (other) => other != line && other.product.id == line.product.id)
          .fold<int>(quantity,
              (sum, other) => sum + (other.weightGrams ?? other.quantity));
      if (quantity > line.quantity &&
          !await _chooseProductRooms(line.product, required)) {
        return;
      }
      if (!mounted || !_cart.contains(line)) return;
      line.setQuantity(quantity);
      _trimRoomPicks(line.product.id);
      _cartChanged();
    });
  }

  Future<void> _editLineQuantity(_PosCartLine line) async {
    if (_saving || _choosingRooms) return;
    final quantity = await showDialog<int>(
        context: context,
        builder: (_) => _PosProductQuantityDialog(
            product: line.product,
            isWeightProduct: false,
            initialQuantity: line.quantity));
    if (quantity != null) await _changeLineQuantity(line, quantity);
  }

  void _removeCartLine(_PosCartLine line) {
    if (_saving || _choosingRooms) return;
    _cart.remove(line);
    _trimRoomPicks(line.product.id);
    line.dispose();
    _cartChanged(membership: true);
  }

  bool _sameProduct(PosProduct first, PosProduct second) {
    if (first.id == second.id) return true;
    final firstBarcode = first.barcode?.trim().toLowerCase() ?? '';
    final secondBarcode = second.barcode?.trim().toLowerCase() ?? '';
    if (firstBarcode.isNotEmpty && firstBarcode == secondBarcode) return true;
    final firstSku = first.sku.trim().toLowerCase();
    final secondSku = second.sku.trim().toLowerCase();
    return firstSku.isNotEmpty &&
        firstSku == secondSku &&
        first.name.trim().toLowerCase() == second.name.trim().toLowerCase();
  }

  bool _scanInProgress = false;

  Future<void> _scan() async {
    if (_scanInProgress || _saving) return;
    _scanInProgress = true;
    try {
      while (mounted && !_saving) {
        final product = await widget.onScan();
        if (product == null || !mounted) break;
        final added = await _addProduct(product);
        if (!added) break;
      }
    } finally {
      _scanInProgress = false;
    }
  }

  List<Map<String, dynamic>> _requestItems() => _cart
      .map((line) => {
            'productId': line.product.id,
            'quantity': line.quantity,
            'weightGrams': line.weightGrams,
            if (_isManualProduct(line.product)) ...{
              'manualName': line.product.name,
              'manualPrice': line.unitPrice,
            },
          })
      .toList(growable: false);

  Future<void> _hold({bool startNewBillAfterHold = false}) async {
    if (_saving || _barcodeQueue.pending > 0 || _additionQueue.pending > 0) {
      return;
    }
    if (_cart.isEmpty) {
      setState(() => _error = 'Add at least one product to hold a bill.');
      return;
    }
    final phoneError = validateNepalPhone(
      _customerPhone.text,
      optional: true,
    );
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.holdPosSale(
        items: _cart
            .map((line) => {
                  'productId': line.product.id,
                  'quantity': line.quantity,
                  'weightGrams': line.weightGrams,
                  'productName': line.product.name,
                  'sku': line.product.sku,
                  'price': line.unitPrice,
                  'cataloguePrice': line.product.price,
                  'unitLabel': line.product.unitLabel,
                })
            .toList(growable: false),
        customerName: _customerName.text.trim().isEmpty
            ? null
            : _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim().isEmpty
            ? null
            : _customerPhone.text.trim(),
        customerId: _selectedCustomer?.id,
      );
      if (mounted) {
        Navigator.pop(context);
        if (startNewBillAfterHold) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onNewBill();
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  Future<void> _completeSale() async {
    if (_checkoutInProgress ||
        _saving ||
        _barcodeQueue.pending > 0 ||
        _additionQueue.pending > 0) {
      return;
    }
    _checkoutInProgress = true;
    try {
      await _submitSale();
    } finally {
      _checkoutInProgress = false;
    }
  }

  Future<void> _submitSale() async {
    final payingFonepay = _paymentMethod == 'ESEWA';
    if (_cart.isEmpty) {
      setState(() => _error = 'Add products before completing the bill.');
      return;
    }
    if (_cart.any((line) =>
        line.weightGrams == null &&
        int.tryParse(line.quantityController.text.trim()) != line.quantity)) {
      setState(() => _error = 'Enter a valid quantity for every bill item.');
      return;
    }
    final enteredDiscount = double.tryParse(_discount.text.trim());
    if (enteredDiscount == null ||
        !enteredDiscount.isFinite ||
        enteredDiscount < 0 ||
        (_discountIsPercent
            ? enteredDiscount > 100
            : enteredDiscount > _subtotal)) {
      setState(() => _error = _discountIsPercent
          ? 'Enter a percentage from 0% to 100%.'
          : 'Enter a valid discount not greater than the subtotal.');
      return;
    }
    final discount = _discountAmount;
    final vatRate = double.tryParse(_vatRate.text.trim());
    if (vatRate == null || !vatRate.isFinite || vatRate < 0 || vatRate > 100) {
      setState(() => _error = 'Enter a VAT rate from 0% to 100%.');
      return;
    }
    final enteredPaidNow = _paymentMethod == 'PENDING'
        ? double.tryParse(_paidNow.text.trim())
        : _total;
    if (enteredPaidNow == null ||
        !enteredPaidNow.isFinite ||
        enteredPaidNow < 0 ||
        enteredPaidNow > _total) {
      setState(() =>
          _error = 'Enter an amount paid from Rs. 0 up to ${_money(_total)}.');
      return;
    }
    final phoneError = validateNepalPhone(
      _customerPhone.text,
      optional: true,
    );
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The server transaction checks stock and rooms atomically online.
      // Local checkout validates both inside saveBill under its writer lock.
      // No duplicate network fetch on the checkout-to-print path.
      final quantities = <String, int>{};
      for (final line in _cart) {
        // Manual items are deliberately outside inventory and therefore do
        // not require a source-room selection.
        if (_isManualProduct(line.product)) continue;
        quantities[line.product.id] = (quantities[line.product.id] ?? 0) +
            (line.weightGrams ?? line.quantity);
      }
      for (final entry in quantities.entries) {
        final chosen = (_roomPicks ?? const <RoomPick>[])
            .where((p) => p.productId == entry.key)
            .fold<int>(0, (sum, p) => sum + p.quantity);
        if (chosen != entry.value) {
          throw StateError(
              'Choose the source room beside each bill item before paying.');
        }
      }
      _roomSelectionNeedsRefresh = false;
      if (payingFonepay) {
        await _payWithFonepay(discount, vatRate);
        return;
      }
      final localFirst =
          widget.allowOfflineSync && !_saveOnThisComputer && !payingFonepay;
      final sale = localFirst
          ? await _createLocalSale(
              discount: discount,
              vatRate: vatRate,
              queueForSync: true,
            )
          : _saveOnThisComputer
              ? await _createLocalSale(discount: discount, vatRate: vatRate)
              : await widget.api.createPosSale(
                  roomPicks: _roomPicks?.map((pick) => pick.toJson()).toList(),
                  idempotencyKey: _idempotencyKey,
                  items: _requestItems(),
                  discount: discount,
                  vatRate: vatRate,
                  paymentMethod: _paymentMethod,
                  paidAmount:
                      _paymentMethod == 'PENDING' ? enteredPaidNow : null,
                  paidNowMethod:
                      _paymentMethod == 'PENDING' ? _paidNowMethod : null,
                  customerName: _customerName.text.trim().isEmpty
                      ? null
                      : _customerName.text.trim(),
                  customerPhone: _customerPhone.text.trim().isEmpty
                      ? null
                      : _customerPhone.text.trim(),
                  customerId: _selectedCustomer == null ||
                          _selectedCustomer!.id.startsWith('local-customer-')
                      ? null
                      : _selectedCustomer!.id,
                  heldSaleId: widget.heldSale?.id,
                  expectedTotal: _total,
                  cataloguePriceChanges:
                      _priceChanges.isEmpty ? null : _priceChanges,
                  unitPrices: {
                    for (final line in _cart) line.product.id: line.unitPrice
                  },
                );
      if (mounted) Navigator.pop(context, sale);
    } on ApiNetworkException {
      if (!mounted) return;
      if (payingFonepay) {
        setState(() {
          _saving = false;
          _error =
              'eSewa connection interrupted. Retry the same checkout; no offline bill was created.';
        });
        return;
      }
      try {
        final sale = await _createLocalSale(
            discount: discount, vatRate: vatRate, queueForSync: true);
        if (mounted) Navigator.pop(context, sale);
      } catch (error) {
        if (mounted) {
          setState(() {
            _error =
                'Could not reach the server, and the local bill could not be saved: $error';
            _saving = false;
          });
        }
      }
    } on ApiTimeoutException {
      if (!mounted) return;
      if (payingFonepay) {
        setState(() {
          _saving = false;
          _error =
              'eSewa response is uncertain. Reopen the same checkout to reconcile it; no offline bill was created.';
        });
        return;
      }
      try {
        final sale = await _createLocalSale(
            discount: discount, vatRate: vatRate, queueForSync: true);
        if (mounted) Navigator.pop(context, sale);
      } catch (error) {
        if (mounted) {
          setState(() {
            _error =
                'The server timed out, and the local bill could not be saved: $error';
            _saving = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  Future<void> _payWithFonepay(double discount, double vatRate) async {
    if (!_total.isFinite || _total <= 0) {
      throw StateError(
          'QR payment requires a payable amount greater than NPR 0.00.');
    }
    if (widget.operatorId.isEmpty) {
      throw StateError('Sign in as a cashier to confirm a QR payment.');
    }
    final completion = await showDialog<PosSale>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StaticFonepayPaymentDialog(
              amount: _total,
              cashierId: widget.operatorId,
              qrAsset: AppConstants.staticEsewaQrAsset,
              confirmationReference: 'CASHIER-$_idempotencyKey',
              paymentMethod: _paymentMethod,
              providerName: 'eSewa',
              onVerified: (verification) async {
                if (_roomSelectionNeedsRefresh) {
                  throw StateError(
                      'Close payment and edit the source room beside the bill item before retrying.');
                }
                if (_saveOnThisComputer) {
                  return _createLocalSale(
                      discount: discount,
                      vatRate: vatRate,
                      manualVerification: verification);
                }
                return widget.api.createPosSale(
                    roomPicks:
                        _roomPicks?.map((pick) => pick.toJson()).toList(),
                    idempotencyKey: _idempotencyKey,
                    items: _requestItems(),
                    discount: discount,
                    vatRate: vatRate,
                    paymentMethod: _paymentMethod,
                    manualVerification: verification.request,
                    customerName: _customerName.text.trim().isEmpty
                        ? null
                        : _customerName.text.trim(),
                    customerPhone: _customerPhone.text.trim().isEmpty
                        ? null
                        : _customerPhone.text.trim(),
                    customerId:
                        _selectedCustomer?.id.startsWith('local-customer-') ==
                                true
                            ? null
                            : _selectedCustomer?.id,
                    expectedTotal: _total,
                    cataloguePriceChanges:
                        _priceChanges.isEmpty ? null : _priceChanges,
                    unitPrices: {
                      for (final line in _cart) line.product.id: line.unitPrice
                    }).onError<ApiResponseException>((error, stack) {
                  if (error.statusCode == 409) {
                    _roomSelectionNeedsRefresh = true;
                  }
                  Error.throwWithStackTrace(error, stack);
                });
              },
              onPrint: widget.printSale ??
                  (sale) async {
                    final bytes = await PosReceiptService.createPdf(sale,
                        paperWidthMm: widget.paperWidthMm);
                    await BillPdfArchiveService.save(sale, bytes);
                    return Printing.layoutPdf(
                        name: BillPdfArchiveService.fileName(sale),
                        format: PosReceiptService.pageFormat(sale,
                            paperWidthMm: widget.paperWidthMm),
                        dynamicLayout: false,
                        onLayout: (_) async => bytes);
                  },
            ));
    if (!mounted) return;
    if (completion != null) {
      Navigator.pop(context, completion.withAutoPrintAllowed(false));
    }
    if (_roomSelectionNeedsRefresh) {
      _roomSelectionNeedsRefresh = false;
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.f8): () {
          if (!_saving) unawaited(_completeSale());
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_saving) Navigator.of(context).pop();
        },
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? MediaQuery.sizeOf(context).width * .92 : 760,
            maxHeight:
                isDesktop ? MediaQuery.sizeOf(context).height * .90 : 820,
          ),
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildDialogHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(flex: 7, child: _buildWindowsItemsColumn()),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _cartTotals,
                      builder: (_, __, ___) => _buildWindowsBillDetailsColumn(),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsItemsColumn() => Column(
        children: [
          _buildWindowsCustomerCard(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSearchField(isDesktop: true)),
              const SizedBox(width: 8),
              BillingIconButton.outlined(
                tooltip: 'Scan barcode',
                onPressed: _saving ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildWindowsProductPanel()),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _buildErrorMessage(),
          ],
        ],
      );

  Widget _buildWindowsProductPanel() => AppSurface(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                BillingText('PRODUCTS',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                BillingText('${_matches.length} found',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (_searching)
                  const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                TextButton.icon(
                    onPressed: _saving ? null : _addManualItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const BillingText('Manual item')),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: RepaintBoundary(child: _buildMatches())),
          ],
        ),
      );

  Widget _buildWindowsCustomerCard() => AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded, size: 17),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _customerName,
                enabled: !_saving,
                onChanged: (_) => _customerDetailsChanged(byName: true),
                decoration: const BillingInputDecoration(
                  hintText: 'Customer name (optional)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _customerPhone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                inputFormatters: nepalPhoneInputFormatters,
                onChanged: (_) => _customerDetailsChanged(byName: false),
                decoration: const BillingInputDecoration(
                  hintText: 'Phone (optional)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: _saving ? null : _selectRegisteredCustomer,
              icon: const Icon(Icons.people_alt_outlined, size: 15),
              label: const BillingText('Select existing'),
            ),
          ],
        ),
      );
  // ignore: unused_element
  Widget _buildWindowsItemsCard() => ValueListenableBuilder<int>(
        valueListenable: _cartMembership,
        builder: (_, __, ___) => _buildWindowsItemsCardContents(),
      );

  Widget _buildWindowsItemsCardContents() => AppSurface(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                BillingText(
                  'BILL ITEMS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navigationSelected,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _cartTotals,
                    builder: (_, __, ___) => BillingText(
                      '${_cart.fold<int>(0, (sum, line) => sum + (line.weightGrams == null ? line.quantity : 1))} items',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
                BillingText(
                  'F2 to search',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: Scrollbar(
                child: _cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 38, color: AppColors.outline),
                            const SizedBox(height: 8),
                            BillingText('No items added yet',
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 3),
                            BillingText(
                              'Your bill stays visible while you search products.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _buildCart(),
              ),
            ),
            const Divider(height: 12),
            Row(
              children: [
                BillingText(
                  'PRODUCTS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                BillingText('${_matches.length} found',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (_searching)
                  const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 3,
              child: Scrollbar(child: _buildMatches()),
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(child: _buildSearchField(isDesktop: true)),
                const SizedBox(width: 8),
                BillingIconButton.outlined(
                  tooltip: 'Scan barcode',
                  onPressed: _saving ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildWindowsBillDetailsColumn() => Column(
        children: [
          Expanded(
            flex: 5,
            child: AppSurface(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BillingText(
                          'Bill items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _cartTotals,
                        builder: (_, __, ___) => BillingText(
                          '${_cart.fold<int>(0, (sum, line) => sum + (line.weightGrams == null ? line.quantity : 1))} items',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      BillingIconButton(
                        tooltip: 'Clear all',
                        onPressed: _saving || _cart.isEmpty
                            ? null
                            : () {
                                for (final line in _cart) {
                                  line.dispose();
                                }
                                _cart.clear();
                                _cartChanged(membership: true);
                              },
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                    ],
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: Scrollbar(
                      child: _cart.isEmpty
                          ? const Center(
                              child: BillingText('No items added yet'))
                          : _buildCart(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _paymentMethod,
                        decoration: const BillingInputDecoration(
                          labelText: 'Payment method',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'CASH', child: BillingText('Cash')),
                          DropdownMenuItem(
                              value: 'ESEWA', child: BillingText('eSewa / QR')),
                          DropdownMenuItem(
                              value: 'PENDING',
                              child: BillingText('Pending balance')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                  _paymentMethod = value ?? 'CASH';
                                  _error = null;
                                }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: BillingText('Rs')),
                        ButtonSegment(value: true, label: BillingText('%')),
                      ],
                      selected: {_discountIsPercent},
                      onSelectionChanged: (value) => setState(() {
                        _discountIsPercent = value.first;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: BillingInputDecoration(
                          labelText: _discountIsPercent
                              ? 'Discount percentage (%)'
                              : 'Discount amount',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _vatRate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const BillingInputDecoration(
                          labelText: 'VAT (%)',
                          hintText: '0',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.allowOfflineSync)
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Checkbox(
                            value: _saveOnThisComputer,
                            visualDensity: VisualDensity.compact,
                            onChanged: _saving
                                ? null
                                : (value) => setState(
                                    () => _saveOnThisComputer = value ?? false),
                          ),
                        ),
                        const Expanded(
                          child: BillingText('Save on this computer only'),
                        ),
                        const Tooltip(
                          message:
                              'Bills and customer details stay in C:/Ramprasad store/bills/.',
                          child: Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                _billAmountRow('Subtotal', _subtotal),
                if (_discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _billAmountRow(
                    'Discount',
                    -_discountAmount,
                  ),
                ],
                if ((double.tryParse(_vatRate.text.trim()) ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  _billAmountRow(
                    'VAT (${(double.tryParse(_vatRate.text.trim()) ?? 0).toStringAsFixed(2)}%)',
                    _vatAmount,
                  ),
                ],
                Divider(color: AppColors.outline),
                Row(
                  children: [
                    Expanded(
                      child: BillingText(
                        'TOTAL',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    BillingText(
                      _money(_total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.successText,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _hold,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const BillingText('Hold'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _completeSale,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: BillingText(
                            ['FONEPAY', 'ESEWA'].contains(_paymentMethod)
                                ? 'Pay'
                                : _saveOnThisComputer
                                    ? 'Save local bill (F8)'
                                    : 'Create bill (F8)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _billAmountRow(String label, double amount) => Row(
        children: [
          Expanded(
              child: BillingText(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          BillingText(
            _money(amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );

  String _todayDateLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildDialogHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSearchField(isDesktop: false),
        ),
        if (_error != null) _buildErrorMessage(),
        if (_searching)
          const LinearProgressIndicator(minHeight: 2)
        else
          SizedBox(height: 148, child: _buildMatches()),
        const Divider(height: 1),
        Expanded(child: _buildCart()),
        ValueListenableBuilder<int>(
          valueListenable: _cartTotals,
          builder: (_, __, ___) => _buildCheckoutControls(),
        ),
      ],
    );
  }

  Widget _buildDialogHeader() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Container(
        height: 60,
        color: AppColors.header,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: BillingText(
                widget.heldSale == null
                    ? 'Create New Invoice'
                    : 'Resume Held Bill',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            BillingText(
              _todayDateLabel(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const BillingText(
                'Retail sale',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const Spacer(),
            BillingText(
              'Bill number: assigned on save',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            if (widget.localSync != null) ...[
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: widget.localSync!,
                builder: (context, _) {
                  final sync = widget.localSync!;
                  final label = sync.online == false
                      ? 'Offline'
                      : sync.running
                          ? 'Syncing'
                          : 'Synced';
                  final color = sync.online == false
                      ? Colors.amber.shade200
                      : Colors.greenAccent.shade100;
                  return Tooltip(
                    message: sync.error ??
                        (sync.pending > 0
                            ? '${sync.pending} bill(s) waiting to sync'
                            : 'Billing data $label'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sync.online == false
                              ? Icons.cloud_off_outlined
                              : sync.running
                                  ? Icons.sync_rounded
                                  : Icons.cloud_done_outlined,
                          size: 15,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$label${sync.pending > 0 ? ' ${sync.pending}' : ''}',
                          style: TextStyle(color: color, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            BillingIconButton(
              tooltip: 'Close',
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
              ),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: BillingText(
              widget.heldSale == null ? 'New bill' : 'Resume held bill',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.windows)
            BillingText(
              'F2 Search · F8 Complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          BillingIconButton(
            tooltip: 'Add manual item',
            onPressed: _saving ? null : _addManualItem,
            icon: const Icon(Icons.add_box_outlined),
          ),
          BillingIconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({required bool isDesktop}) {
    return TextField(
      controller: _search,
      focusNode: _searchFocus,
      autofocus: isDesktop,
      onChanged: _onSearchChanged,
      onSubmitted: _submitBarcode,
      decoration: BillingInputDecoration(
        labelText: isDesktop
            ? 'Scan barcode or search product / SKU'
            : 'Search product, SKU or barcode',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: isDesktop
            ? null
            : BillingIconButton(
                tooltip: 'Scan barcode',
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.errorPill,
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.errorText, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: BillingText(
                _error!,
                style: TextStyle(color: AppColors.errorText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatches() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_matches.isEmpty) {
      return Center(
        child: BillingText(
          _search.text.isEmpty
              ? 'Search or scan to add products.'
              : 'No matching products.',
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      // The catalogue is already cached and indexed locally; do not hide
      // imported items behind the old 60-card cap.
      itemCount: _matches.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 170,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final product = _matches[index];
        return InkWell(
          key: ValueKey(product.id),
          borderRadius: BorderRadius.circular(8),
          onTap: _saving || (!product.isUnlimited && product.available <= 0)
              ? null
              : () => _addProduct(product),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline, width: .5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 64,
                  child: ProductThumbnail(
                    imageUrl: product.imageUrl ?? '',
                    size: 64,
                    width: double.infinity,
                    height: 64,
                    backgroundColor: AppColors.thumbnailGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 26,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.name,
                      textAlign: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _money(product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  product.isUnlimited
                      ? 'Unlimited stock'
                      : StockSummary.availableLabel(product),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                      ),
                ),
                const Spacer(),
                SizedBox(
                  height: 26,
                  child: FilledButton(
                    onPressed: _saving ||
                            (!product.isUnlimited && product.available <= 0)
                        ? null
                        : () => _addProduct(product),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
        /* AppRowCard(
            key: ValueKey(product.id),
            title: product.name,
            titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
            subtitleStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            leadingSize: 76,
            subtitle:
                '${_money(product.price)}\nAvailable: ${StockSummary.availableLabel(product)}',
            leading: product.imageUrl?.isNotEmpty == true
                ? ProductThumbnail(
                    imageUrl: product.imageUrl!,
                    size: 76,
                    width: 76,
                    height: 76,
                    backgroundColor: AppColors.thumbnailGreen,
                    borderRadius: BorderRadius.circular(AppRadii.thumbnail),
                  )
                : BillingText(
                    product.name.isEmpty ? '?' : product.name.substring(0, 1),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
            tint: AppColors.thumbnailGreen,
            trailing: FilledButton.icon(
              onPressed: _saving || product.available <= 0
                  ? null
                  : () => _addProduct(product),
              icon: const Icon(Icons.add_circle_outline),
              style: FilledButton.styleFrom(
                minimumSize: const Size(92, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              label: const BillingText('Add',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ); */
      },
    );
  }

  Widget _buildCart() => ValueListenableBuilder<int>(
        valueListenable: _cartMembership,
        builder: (_, __, ___) => Column(children: [
          if (_choosingRooms) const LinearProgressIndicator(),
          Expanded(child: _buildCartList()),
        ]),
      );

  List<Map<String, dynamic>> get _priceChanges => {
        for (final line in _cart)
          if (!_isManualProduct(line.product) &&
              line.unitPrice != line.product.price)
            line.product.id: {
              'productId': line.product.id,
              'expectedPrice': line.product.price,
              'price': line.unitPrice,
            }
      }.values.toList();

  Future<void> _editPrice(_PosCartLine line) async {
    final quantity = line.weightGrams == null
        ? line.quantity.toDouble()
        : line.weightGrams! / 1000;
    final rate = TextEditingController(text: line.unitPrice.toStringAsFixed(2));
    final amount = TextEditingController(
        text: _roundBillMoney(line.unitPrice * quantity).toStringAsFixed(2));
    final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
                title: BillingText('Edit price: ${line.product.name}'),
                content: SizedBox(
                    width: 400,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const BillingText(
                          'The new unit price also becomes the current product price when this bill is saved. Line total is rounded to two decimals.'),
                      BillingTextFormField(
                          controller: rate,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const BillingInputDecoration(
                              labelText: 'Unit price (NPR)'),
                          onChanged: (value) {
                            final price = double.tryParse(value);
                            if (price != null && price.isFinite) {
                              amount.text = _roundBillMoney(price * quantity)
                                  .toStringAsFixed(2);
                            }
                          }),
                      BillingTextFormField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const BillingInputDecoration(
                              labelText: 'Line total (NPR)'),
                          onChanged: (value) {
                            final total = double.tryParse(value);
                            if (total != null && total.isFinite) {
                              rate.text = _roundBillMoney(total / quantity)
                                  .toStringAsFixed(2);
                            }
                          }),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: rate,
                        builder: (_, value, __) => BillingText(
                            'Calculated line total: NPR ${_roundBillMoney((double.tryParse(value.text) ?? 0) * quantity).toStringAsFixed(2)}'),
                      ),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const BillingText('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final price = double.tryParse(rate.text);
                        if (price != null &&
                            price.isFinite &&
                            price >= 0 &&
                            price <= 999999999) {
                          Navigator.pop(context, _roundBillMoney(price));
                        }
                      },
                      child: const BillingText('Save price'))
                ]));
    // Controllers are disposed after the route's closing animation completes.
    Future.delayed(const Duration(seconds: 1), () {
      rate.dispose();
      amount.dispose();
    });
    if (result != null && mounted) {
      for (final item in _cart.where((i) => i.product.id == line.product.id)) {
        item.setPrice(result);
      }
      _cartChanged();
    }
  }

  Widget _inlinePriceField(_PosCartLine line, bool isTotal) {
    final controller = isTotal ? line.totalController : line.priceController;
    return BillingTextFormField(
      key: ValueKey('${line.product.id}-${isTotal ? 'total' : 'rate'}'),
      controller: controller,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue;
          final value = double.tryParse(newValue.text);
          final price = isTotal ? (value ?? -1) / line.priceQuantity : value;
          return RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(newValue.text) &&
                  price != null &&
                  price.isFinite &&
                  price >= 0 &&
                  price <= 999999999
              ? newValue
              : oldValue;
        }),
      ],
      decoration: BillingInputDecoration(
        labelText: isTotal ? 'Line total (NPR)' : 'Unit price (NPR)',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: (text) {
        final value = double.tryParse(text);
        if (value == null || !value.isFinite || value < 0) return;
        final price = isTotal ? value / line.priceQuantity : value;
        if (!price.isFinite || price > 999999999) return;
        for (final item
            in _cart.where((i) => i.product.id == line.product.id)) {
          item.setPrice(_roundBillMoney(price), editing: controller);
        }
        _cartChanged();
      },
      onEditingComplete: () {
        line.syncPrices();
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return const Center(child: BillingText('Bill is empty.'));
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final line = _cart[index];
        return ListenableBuilder(
          key: ObjectKey(line),
          listenable: line,
          builder: (context, _) {
            final total = line.unitPrice *
                (line.weightGrams == null
                    ? line.quantity
                    : line.weightGrams! / 1000);
            return Padding(
              key: ObjectKey(line),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final quantityControls = line.weightGrams == null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BillingIconButton(
                                tooltip: 'Decrease quantity',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                    width: 30, height: 30),
                                iconSize: 16,
                                onPressed: _saving
                                    ? null
                                    : () {
                                        if (line.quantity > 1) {
                                          unawaited(_changeLineQuantity(
                                              line, line.quantity - 1,
                                              delta: -1));
                                        } else {
                                          _removeCartLine(line);
                                        }
                                      },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: compact ? 48 : 76,
                                child: BillingTextFormField(
                                  key: ObjectKey(line),
                                  controller: line.quantityController,
                                  enabled: !_saving,
                                  readOnly: _assignedRoomProducts
                                      .contains(line.product.id),
                                  onTap: _assignedRoomProducts
                                          .contains(line.product.id)
                                      ? () => _editLineQuantity(line)
                                      : null,
                                  onChanged: (value) {
                                    final quantity = int.tryParse(value);
                                    if (quantity == null ||
                                        quantity <= 0 ||
                                        _saving ||
                                        _choosingRooms) {
                                      return;
                                    }
                                    line.quantity = quantity;
                                    final required = _cart
                                        .where((other) =>
                                            other.product.id == line.product.id)
                                        .fold<int>(
                                            0,
                                            (sum, other) =>
                                                sum +
                                                (other.weightGrams ??
                                                    other.quantity));
                                    _roomPicks = [
                                      ...?_roomPicks?.where((p) =>
                                          p.productId != line.product.id),
                                      RoomPick(
                                          productId: line.product.id,
                                          roomId: null,
                                          quantity: required)
                                    ];
                                    _cartChanged();
                                  },
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const BillingInputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                  ),
                                ),
                              ),
                              BillingIconButton(
                                tooltip: 'Increase quantity',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                    width: 30, height: 30),
                                iconSize: 16,
                                onPressed: _saving
                                    ? null
                                    : () {
                                        unawaited(_changeLineQuantity(
                                            line, line.quantity + 1,
                                            delta: 1));
                                      },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          )
                        : BillingText('${line.weightGrams} g');

                    final amountAndRemove = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.allowPriceEditing)
                          BillingIconButton(
                              tooltip: 'Edit unit price / line total',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                  width: 30, height: 30),
                              iconSize: 16,
                              onPressed:
                                  _saving ? null : () => _editPrice(line),
                              icon: const Icon(Icons.edit_outlined)),
                        Flexible(
                            child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BillingText(_money(total)),
                        )),
                        BillingIconButton(
                          tooltip: 'Remove item',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 30, height: 30),
                          iconSize: 16,
                          onPressed: _saving
                              ? null
                              : () {
                                  _removeCartLine(line);
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    );

                    if (compact) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  ProductThumbnail(
                                      imageUrl: line.product.imageUrl ?? '',
                                      size: 40),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: BillingText(
                                      line.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(flex: 5, child: quantityControls),
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: amountAndRemove,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Row(children: [
                            ProductThumbnail(
                                imageUrl: line.product.imageUrl ?? '',
                                size: 56),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BillingText(
                                  line.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            )),
                          ]),
                        ),
                        Expanded(flex: 4, child: quantityControls),
                        Expanded(flex: 2, child: amountAndRemove),
                      ],
                    );
                  },
                ),
                if (widget.allowPriceEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Row(children: [
                      Expanded(child: _inlinePriceField(line, false)),
                      const SizedBox(width: 8),
                      Expanded(child: _inlinePriceField(line, true)),
                    ]),
                  ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildCheckoutControls() {
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerName,
                  onChanged: (_) => _customerDetailsChanged(byName: true),
                  decoration: const BillingInputDecoration(
                    labelText: 'Customer (optional)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customerPhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: nepalPhoneInputFormatters,
                  onChanged: (_) => _customerDetailsChanged(byName: false),
                  decoration: const BillingInputDecoration(
                    labelText: 'Customer phone (optional)',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          if (_paymentMethod == 'PENDING') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paidNow,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const BillingInputDecoration(
                      labelText: 'Paying now',
                      prefixText: 'Rs. ',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _paidNowMethod,
                    decoration: const BillingInputDecoration(
                      labelText: 'Received by',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'CASH', child: BillingText('Cash')),
                    ],
                    onChanged: (value) => setState(() {
                      _paidNowMethod = value ?? 'CASH';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: BillingText(
                'Remaining in pending cash: ${_money((_total - (double.tryParse(_paidNow.text.trim()) ?? 0)).clamp(0, _total).toDouble())}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: BillingText('Amount')),
              ButtonSegment(value: true, label: BillingText('Percentage')),
            ],
            selected: {_discountIsPercent},
            onSelectionChanged: (value) => setState(() {
              _discountIsPercent = value.first;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: BillingInputDecoration(
                    labelText: _discountIsPercent
                        ? 'Discount percentage (%)'
                        : 'Discount amount',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _paymentMethod,
                  decoration: const BillingInputDecoration(
                    labelText: 'Payment',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: BillingText('Cash')),
                    DropdownMenuItem(
                      value: 'ESEWA',
                      child: BillingText('eSewa / QR'),
                    ),
                    DropdownMenuItem(
                        value: 'PENDING', child: BillingText('Pending')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _paymentMethod = value ?? 'CASH';
                            _error = null;
                          }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BillingText('Subtotal ${_money(_subtotal)}'),
              BillingText(
                'Total ${_money(_total)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _hold,
                icon: const Icon(Icons.pause_circle_outline),
                label: const BillingText('Hold'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _completeSale,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: BillingText(
                    _paymentMethod == 'ESEWA' ? 'Pay' : 'Create bill'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(double amount) =>
      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

class _PosCartLine extends ChangeNotifier {
  _PosCartLine(
    this.product, {
    int quantity = 1,
    this.weightGrams,
  })  : _quantity = quantity,
        quantityController = TextEditingController(text: '$quantity') {
    syncPrices();
  }

  final PosProduct product;
  double? _editedPrice;
  double get unitPrice => _editedPrice ?? product.price;
  final priceController = TextEditingController();
  final totalController = TextEditingController();
  double get priceQuantity =>
      weightGrams == null ? quantity.toDouble() : weightGrams! / 1000;

  void syncPrices({TextEditingController? editing}) {
    if (editing != priceController) {
      priceController.text = unitPrice.toStringAsFixed(2);
    }
    if (editing != totalController) {
      totalController.text =
          _roundBillMoney(unitPrice * priceQuantity).toStringAsFixed(2);
    }
  }

  void setPrice(double price, {TextEditingController? editing}) {
    _editedPrice = price;
    syncPrices(editing: editing);
    notifyListeners();
  }

  final TextEditingController quantityController;
  int _quantity;
  int get quantity => _quantity;
  set quantity(int value) {
    if (_quantity == value) return;
    _quantity = value;
    syncPrices();
    notifyListeners();
  }

  final int? weightGrams;

  void setQuantity(int value) {
    quantity = value;
    quantityController.value = TextEditingValue(
      text: '$value',
      selection: TextSelection.collapsed(offset: '$value'.length),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    totalController.dispose();
    super.dispose();
  }
}
