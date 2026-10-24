import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../models/pos_models.dart';
import '../../models/scanned_product_barcode.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/pos_receipt_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/product_thumbnail.dart';
import 'barcode_scanner_screen.dart';
import 'admin_billing_staff_screen.dart';

enum AdminBillingSection {
  dashboard,
  essential,
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

bool _isWeightUnitLabel(String label) =>
    RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
        .hasMatch(label);

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({
    super.key,
    required this.api,
    this.isBillingStaff = false,
  });

  final ApiService api;
  final bool isBillingStaff;

  @override
  State<AdminBillingScreen> createState() => AdminBillingScreenState();
}

class AdminBillingScreenState extends State<AdminBillingScreen> {
  bool get _isWindowsOperatorMode =>
      !widget.isBillingStaff &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;

  late final AdminApiService _adminApi = AdminApiService(widget.api);
  PosOverview? _overview;
  PosOverview? _reportOverview;
  List<PosSale> _sales = const [];
  PosSalesPage? _pendingPaymentPage;
  int _salesPage = 1;
  int _salesPageSize = 50;
  int _salesTotal = 0;
  int _pendingPaymentPageNumber = 1;
  List<PosRefund> _refunds = const [];
  List<PosHeldSale> _heldSales = const [];
  List<PosExchange> _exchanges = const [];
  String? _exchangeError;
  DateTime? _billHistoryDay;
  DateTime? _reportDay;
  bool _loading = true;
  String? _error;
  bool _working = false;
  int _paperWidthMm = 80;
  final _scrollController = ScrollController();
  final _customerSearch = TextEditingController();
  final _sectionKeys = <AdminBillingSection, GlobalKey>{
    for (final section in AdminBillingSection.values) section: GlobalKey(),
  };

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _border => Theme.of(context).colorScheme.outlineVariant;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  void dispose() {
    _scrollController.dispose();
    _customerSearch.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPaperWidth());
    unawaited(_load());
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
          content: Text(
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
          content: Text(
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
  String? get _reportDayKey => _formatDayKey(_reportDay);

  Future<void> _load({int? salesPage, int? pendingPage}) async {
    final requestedSalesPage = salesPage ?? _salesPage;
    final requestedPendingPage = pendingPage ?? _pendingPaymentPageNumber;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _adminApi.getPosOverview();
      final results = await Future.wait([
        if (_reportDayKey != null) _adminApi.getPosOverview(day: _reportDayKey),
        _adminApi.getPosSales(
          page: requestedSalesPage,
          day: _billHistoryDayKey,
        ),
        if (widget.isBillingStaff)
          Future<List<PosRefund>>.value(const [])
        else
          _adminApi.getPosRefunds(),
        _adminApi.getPosHeldSales(),
        _adminApi.getPosPendingPayments(page: requestedPendingPage),
      ]);
      List<PosExchange> exchanges = const [];
      String? exchangeError;
      try {
        exchanges = await _adminApi.getPosExchanges();
      } catch (error) {
        exchangeError = error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted) return;
      final reportOverview =
          _reportDayKey == null ? overview : results[0] as PosOverview;
      final salesIndex = _reportDayKey == null ? 0 : 1;
      final loadedSalesPage = results[salesIndex] as PosSalesPage;
      setState(() {
        _overview = overview;
        _reportOverview = reportOverview;
        _sales = loadedSalesPage.sales;
        _salesPage = loadedSalesPage.page;
        _salesPageSize = loadedSalesPage.pageSize;
        _salesTotal = loadedSalesPage.total;
        _refunds = results[salesIndex + 1] as List<PosRefund>;
        _heldSales = results[salesIndex + 2] as List<PosHeldSale>;
        _pendingPaymentPage = results[salesIndex + 3] as PosSalesPage;
        _pendingPaymentPageNumber =
            (results[salesIndex + 3] as PosSalesPage).page;
        _exchanges = exchanges;
        _exchangeError = exchangeError;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _newBill(
      {PosHeldSale? heldSale, PosProduct? scannedProduct}) async {
    final completedSale = await showDialog<PosSale>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PosBillDialog(
        api: _adminApi,
        heldSale: heldSale,
        scannedProduct: scannedProduct,
        onScan: _scanProduct,
      ),
    );
    if (!mounted) return;
    await _load();
    if (completedSale != null && mounted) {
      var printMessage = '';
      if (defaultTargetPlatform == TargetPlatform.windows) {
        try {
          final printed = await Printing.layoutPdf(
            name: completedSale.receiptNumber,
            format: PosReceiptService.pageFormat(
              completedSale,
              paperWidthMm: _paperWidthMm,
            ),
            onLayout: (_) => PosReceiptService.createPdf(
              completedSale,
              paperWidthMm: _paperWidthMm,
            ),
          );
          printMessage = printed
              ? ' Receipt sent to the printer.'
              : ' Receipt was not printed.';
        } catch (error) {
          printMessage =
              ' Bill is confirmed; receipt printing failed: ${error.toString().replaceFirst('Exception: ', '')}';
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bill ${completedSale.receiptNumber} completed.$printMessage',
          ),
        ),
      );
    }
  }

  void startNewBill() {
    unawaited(_newBill());
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
    final scanned = await Navigator.of(context).push<ScannedProductBarcode>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || !mounted) return null;
    try {
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
          const SnackBar(content: Text('No product matched that barcode.')),
        );
      }
      return product;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
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
        title: Text(type == 'CASH_IN' ? 'Add cash to register' : 'Remove cash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: noteController,
              maxLength: 240,
              decoration: const InputDecoration(labelText: 'Reason / note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Record'),
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
    final amountController = TextEditingController(
      text: (sale.total - sale.refundedAmount).toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    var restock = false;
    final values =
        await showDialog<({double amount, String reason, bool restock})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Refund ${sale.receiptNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Refund amount'),
              ),
              TextField(
                controller: reasonController,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              if (sale.refundedAmount == 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: restock,
                  title: const Text('Restore all bill items to stock'),
                  onChanged: (value) =>
                      setDialogState(() => restock = value ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final reason = reasonController.text.trim();
                if (amount == null || amount <= 0 || reason.length < 2) return;
                Navigator.pop(dialogContext, (
                  amount: amount,
                  reason: reason,
                  restock: restock,
                ));
              },
              child: const Text('Submit request'),
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
                  (_isWeightUnitLabel(replacement.unitLabel)
                      ? replacementQuantity / 1000
                      : replacementQuantity);
          final difference = replacementTotal - returnedCredit;
          final replacementIsWeighted =
              replacement != null && _isWeightUnitLabel(replacement.unitLabel);
          return AlertDialog(
            title: Text('Exchange ${sale.receiptNumber}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<PosSaleItem>(
                      initialValue: returnedItem,
                      decoration:
                          const InputDecoration(labelText: 'Item to return'),
                      items: sale.items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                '${item.productName} · ${item.sku}',
                                overflow: TextOverflow.ellipsis,
                              ),
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
                      decoration: InputDecoration(
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
                      decoration: InputDecoration(
                        labelText: 'Replacement product (optional)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: replacementProduct == null
                            ? null
                            : IconButton(
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
                        child: Text(
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
                              title: Text(product.name),
                              subtitle: Text(
                                '${product.sku} · ${_money(product.price)} · '
                                '${product.available} available',
                              ),
                              onTap: product.available <= 0
                                  ? null
                                  : () => setDialogState(() {
                                        replacementProduct = product;
                                        searchController.text = product.name;
                                        matches = [];
                                        replacementQuantityController.text =
                                            _isWeightUnitLabel(
                                                    product.unitLabel)
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
                        decoration: InputDecoration(
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
                      title: const Text('Return item to sellable stock'),
                    ),
                    const SizedBox(height: 8),
                    Text(
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
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Additional payment method',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CASH',
                            child: Text('Cash'),
                          ),
                          DropdownMenuItem(
                            value: 'DIGITAL',
                            child: Text('Digital'),
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
                child: const Text('Cancel'),
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
                child: const Text('Process exchange'),
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
        _isWeightUnitLabel(selectedReplacement.unitLabel);
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
        .showSnackBar(SnackBar(content: Text(message)));
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
    final overview = _overview;
    if (_loading && overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (overview == null && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (overview == null) return const SizedBox.shrink();
    final reportOverview = _reportOverview ?? overview;

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
                  content: Text(_error!),
                  actions: [
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
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
                    label: const Text('New bill'),
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
                    label: const Text('Scan barcode'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showDailyReport,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Daily report'),
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
                      label: const Text('Billing staff'),
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
                'Recent transactions',
                key: _sectionKeys[AdminBillingSection.billHistory],
                actions: [
                  OutlinedButton.icon(
                    onPressed: _selectHistoryDay,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_billHistoryDayKey ?? 'All days'),
                  ),
                  if (_billHistoryDay != null)
                    IconButton(
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
              if (_salesTotal > _salesPageSize)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${((_salesPage - 1) * _salesPageSize) + 1}–'
                        '${(_salesPage * _salesPageSize).clamp(0, _salesTotal)}'
                        ' of $_salesTotal bills',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      IconButton(
                        tooltip: 'Previous bills page',
                        onPressed: _loading || _salesPage <= 1
                            ? null
                            : () => _load(salesPage: _salesPage - 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
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
              if (_sales.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No bills in this period.'),
                )
              else
                ..._sales.map(_saleTile),
              const SizedBox(height: 20),
              _sectionHeading(
                'Customers on this page',
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
                        label: Text(_reportDayKey ?? 'Today'),
                      ),
                      if (_reportDay != null)
                        IconButton(
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
              Text(
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
              color: AppColors.primary.withValues(alpha: 0.13),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(PosOverview overview) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Text(
            '${overview.cashierName ?? 'Admin'} · '
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
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
                Text(
                  'Cash register',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Record cash added to or taken from the drawer.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _working ? null : () => _cashMovement('CASH_IN'),
            child: const Text('Cash in'),
          ),
          OutlinedButton(
            onPressed: _working ? null : () => _cashMovement('CASH_OUT'),
            child: const Text('Cash out'),
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

  Widget _buildCustomers() {
    final customers = <String, List<PosSale>>{};
    for (final sale in _sales) {
      final key = sale.customerPhone?.trim().isNotEmpty == true
          ? sale.customerPhone!.trim()
          : sale.customerName?.trim() ?? '';
      if (key.isNotEmpty) customers.putIfAbsent(key, () => []).add(sale);
    }
    final query = _customerSearch.text.trim().toLowerCase();
    final visibleCustomers = customers.entries.where((entry) {
      if (query.isEmpty) return true;
      final latest = entry.value.first;
      return (latest.customerName ?? '').toLowerCase().contains(query) ||
          (latest.customerPhone ?? '').toLowerCase().contains(query);
    }).take(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _customerSearch,
          decoration: const InputDecoration(
            labelText: 'Search customers in recent bills',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (visibleCustomers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              customers.isEmpty
                  ? 'Customer details captured during checkout will appear here.'
                  : 'No recent billing customers match that search.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...visibleCustomers.map((entry) {
            final sales = entry.value;
            final latestSale = sales.first;
            final name = latestSale.customerName?.trim() ?? '';
            final phone = latestSale.customerPhone?.trim() ?? '';
            final totalSpend = sales.fold<double>(
              0,
              (total, sale) => total + sale.total,
            );
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
              title: Text(name.isNotEmpty ? name : 'Customer'),
              subtitle: Text(
                '${phone.isNotEmpty ? phone : latestSale.receiptNumber} · '
                '${sales.length} bill${sales.length == 1 ? '' : 's'}',
              ),
              trailing: Text(_money(totalSpend)),
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
              child: Text(
                'You are all caught up.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            ...messages.map(
              (message) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(message),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnsAndRefunds() {
    final eligibleSales = _sales.where((sale) =>
        sale.status != 'CANCELLED' &&
        sale.paymentStatus == 'COMPLETED' &&
        sale.refundedAmount < sale.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Returns & exchanges'),
        if (_exchangeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MaterialBanner(
              content: Text(
                'Exchange services are unavailable on the connected backend. '
                'Update the backend and apply the pending POS exchange migration '
                'before using exchanges. $_exchangeError',
              ),
              actions: [
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        if (!widget.isBillingStaff)
          ..._exchanges
              .where((exchange) => exchange.status == 'REFUND_REQUESTED')
              .map(_exchangeReviewTile),
        if (eligibleSales.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Completed bills eligible for a return or exchange will appear here.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...eligibleSales.map(
            (sale) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text(sale.receiptNumber),
              subtitle: Text('Original bill ${_money(sale.total)}'),
              trailing: OutlinedButton(
                onPressed: _working ? null : () => _openExchange(sale),
                child: const Text('Start exchange'),
              ),
            ),
          ),
        if (_exchanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeading('Exchange history'),
          ..._exchanges.take(12).map(_exchangeHistoryTile),
        ],
      ],
    );
  }

  Widget _exchangeReviewTile(PosExchange exchange) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_rounded),
        title: Text('${exchange.receiptNumber} · refund review'),
        subtitle: Text(
          'Refund ${_money(-exchange.difference)} · '
          '${exchange.items.where((item) => item.type == 'RETURN').length} returned item(s)',
        ),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Reject exchange refund',
              onPressed: _working
                  ? null
                  : () => _resolveExchange(exchange, approve: false),
              icon: const Icon(Icons.close_rounded),
            ),
            IconButton(
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
        title: Text('${exchange.receiptNumber} · $amountLabel'),
        subtitle: Text(
          '${exchange.status.replaceAll('_', ' ')} · '
          '${_dateTime(exchange.requestedAt)}',
        ),
        children: [
          for (final item in exchange.items)
            ListTile(
              dense: true,
              title: Text(
                '${item.type == 'RETURN' ? 'Return' : 'Replacement'}: '
                '${item.productName}',
              ),
              subtitle: Text(
                item.weightGrams == null
                    ? 'Qty ${item.quantity}'
                    : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg',
              ),
              trailing: Text(_money(item.lineTotal)),
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
          title: const Text('Approve exchange refund'),
          content: Text(
            'Approve ${_money(-exchange.difference)} for '
            '${exchange.receiptNumber}? The returned and replacement stock '
            'will be adjusted only after approval.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'CASH'),
              child: const Text('Refund cash'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'DIGITAL'),
              child: const Text('Refund digital'),
            ),
          ],
        ),
      );
      if (refundMethod == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject exchange refund'),
          content: Text(
            'Reject the refund difference for ${exchange.receiptNumber}? '
            'The exchange will not change inventory.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reject request'),
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
    final pending = _pendingPaymentPage?.sales ?? const <PosSale>[];
    final page = _pendingPaymentPage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Pending cash',
          actions: [
            if (page != null)
              Chip(
                avatar: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  '${page.total} bill${page.total == 1 ? '' : 's'}',
                ),
              ),
          ],
        ),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
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
                title: Text(
                  sale.customerName?.trim().isNotEmpty == true
                      ? sale.customerName!
                      : 'Customer',
                ),
                subtitle: Text(
                  '${sale.customerPhone ?? 'No phone'} · ${sale.receiptNumber} · '
                  'Bill ${_money(sale.total)} · Paid ${_money(paid)} · '
                  'Due ${_money(outstanding)}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: _working || outstanding <= 0
                      ? null
                      : () => _markPaid(sale),
                  child: const Text('Record payment'),
                ),
                children: [
                  for (final item in sale.items)
                    ListTile(
                      dense: true,
                      title: Text(item.productName),
                      subtitle: Text(
                        item.weightGrams == null
                            ? 'Qty ${item.quantity}'
                            : '${item.weightGrams} g',
                      ),
                      trailing: Text(_money(item.lineTotal)),
                    ),
                  if (sale.paymentCollections.isNotEmpty)
                    const Divider(height: 1),
                  for (final payment in sale.paymentCollections)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        payment.method == 'DIGITAL'
                            ? Icons.phone_android_rounded
                            : Icons.payments_outlined,
                      ),
                      title: Text(
                        '${_money(payment.amount)} · '
                        '${payment.method == 'DIGITAL' ? 'PhonePe / UPI' : 'Cash'}',
                      ),
                      subtitle: Text(
                        '${_dateTime(payment.createdAt)}'
                        '${payment.note?.isNotEmpty == true ? ' · ${payment.note}' : ''}',
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
                child: const Text('Previous'),
              ),
              Text('Page ${page.page} of ${page.pageCount}'),
              TextButton(
                onPressed: _working || page.page >= page.pageCount
                    ? null
                    : () => _load(pendingPage: page.page + 1),
                child: const Text('Next'),
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
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.print_outlined),
            const SizedBox(width: 10),
            const Expanded(child: Text('Receipt paper width')),
            DropdownButton<int>(
              value: _paperWidthMm,
              onChanged: _working
                  ? null
                  : (value) {
                      if (value != null) unawaited(_setPaperWidth(value));
                    },
              items: const [
                DropdownMenuItem(value: 58, child: Text('58 mm')),
                DropdownMenuItem(value: 80, child: Text('80 mm')),
              ],
            ),
          ],
        ),
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
            Text(
              '${_heldSales.length} waiting',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (_heldSales.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Bills you put on hold will be available here.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ..._heldSales.map(
            (held) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: Text(held.customerName?.isNotEmpty == true
                  ? held.customerName!
                  : 'Held bill'),
              subtitle: Text('${held.items.length} item lines'),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Discard held bill',
                    onPressed: () => _perform(
                      () => _adminApi.deletePosHeldSale(held.id),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _newBill(heldSale: held),
                    child: const Text('Resume'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _saleTile(PosSale sale) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        title: Text(sale.receiptNumber),
        subtitle: Text(
          '${_money(sale.total)} · ${sale.paymentStatus == 'PENDING' ? 'Due ${_money(sale.outstandingAmount ?? sale.total)}' : _paymentLabel(sale.paymentMethod)} · ${_dateTime(sale.createdAt)}',
        ),
        trailing: sale.paymentStatus == 'PENDING'
            ? Wrap(
                children: [
                  IconButton(
                    tooltip: 'Record received payment',
                    onPressed: () => _markPaid(sale),
                    icon: const Icon(Icons.payments_outlined),
                  ),
                  if (!widget.isBillingStaff && (sale.paidAmount ?? 0) <= 0)
                    IconButton(
                      tooltip: 'Cancel unpaid bill',
                      onPressed: () => _cancelSale(sale),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                ],
              )
            : sale.status == 'REFUNDED'
                ? const Chip(label: Text('Refunded'))
                : widget.isBillingStaff
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Request refund',
                        onPressed: sale.status == 'CANCELLED'
                            ? null
                            : () => _requestRefund(sale),
                        icon: const Icon(Icons.currency_exchange_rounded),
                      ),
        children: [
          for (final item in sale.items)
            ListTile(
              dense: true,
              title: Text(item.productName),
              subtitle: Text(
                item.weightGrams == null
                    ? 'Qty ${item.quantity} · ${item.sku}'
                    : '${(item.weightGrams! / 1000).toStringAsFixed(3)} kg · ${item.sku}',
              ),
              trailing: Text(_money(item.lineTotal)),
            ),
          if (sale.refundedAmount > 0)
            ListTile(
              dense: true,
              title: const Text('Refunded'),
              trailing: Text(_money(sale.refundedAmount)),
            ),
          for (final payment in sale.paymentCollections)
            ListTile(
              dense: true,
              title: Text(
                '${_money(payment.amount)} · ${_paymentLabel(payment.method)}',
              ),
              subtitle: Text(_dateTime(payment.createdAt)),
            ),
        ],
      ),
    );
  }

  Widget _buildInsights(PosOverview overview) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _insightCard(
            'Top-selling products',
            overview.topProducts.isEmpty
                ? const [Text('No sales recorded today.')]
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
                ? const [Text('No low-stock products.')]
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              Chip(label: Text('${requested.length} pending')),
          ],
        ),
        if (requested.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No refund requests need review.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...requested.map(
            (refund) => Card(
              child: ListTile(
                title:
                    Text('${refund.receiptNumber} · ${_money(refund.amount)}'),
                subtitle: Text(
                    '${refund.reason} · Requested by ${refund.requestedBy}'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Reject refund',
                      onPressed: _working
                          ? null
                          : () => _resolveRefund(refund, approve: false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton(
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
          title: Text('Receive payment · ${sale.receiptNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
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
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: 'Rs ',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Received by'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'DIGITAL',
                    child: Text('PhonePe / UPI (verify manually)'),
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
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              if (validationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
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
              child: const Text('Cancel'),
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
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (payment == null) return;
    await _perform(
      () => _adminApi.recordPosPayment(
        sale.id,
        amount: payment.amount,
        paymentMethod: payment.method,
        note: payment.note,
      ),
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'DIGITAL' => 'PhonePe / UPI',
        'PENDING' => 'Pending',
        _ => 'Cash',
      };

  Future<void> _cancelSale(PosSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel unpaid bill?'),
        content: Text(
          'Cancel ${sale.receiptNumber} and return its items to available stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep bill'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel bill'),
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
        title: Text('Billing report · ${overview.day}'),
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
            child: const Text('Done'),
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

class _PosBillDialog extends StatefulWidget {
  const _PosBillDialog({
    required this.api,
    required this.onScan,
    this.heldSale,
    this.scannedProduct,
  });

  final AdminApiService api;
  final PosHeldSale? heldSale;
  final PosProduct? scannedProduct;
  final Future<PosProduct?> Function() onScan;

  @override
  State<_PosBillDialog> createState() => _PosBillDialogState();
}

class _PosBillDialogState extends State<_PosBillDialog> {
  late final String _idempotencyKey = const Uuid().v4();
  final _search = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _searchFocus = FocusNode();
  Timer? _searchTimer;
  List<PosProduct> _matches = const [];
  final List<_PosCartLine> _cart = [];
  bool _searching = false;
  bool _saving = false;
  String _paymentMethod = 'CASH';
  String? _error;

  @override
  void initState() {
    super.initState();
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
            price: (item['price'] as num).toDouble(),
            unitLabel: item['unitLabel'] as String,
            available: 0,
          ),
          quantity: (item['quantity'] as num).toInt(),
          weightGrams: (item['weightGrams'] as num?)?.toInt(),
        ));
      }
    }
    final scanned = widget.scannedProduct;
    if (scanned != null) _addProduct(scanned);
    unawaited(_searchProducts(''));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _discount.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _isWeightProduct(PosProduct product) =>
      RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
          .hasMatch(product.unitLabel);

  double get _subtotal => _cart.fold<double>(
        0,
        (sum, item) =>
            sum +
            item.product.price *
                (item.weightGrams == null
                    ? item.quantity
                    : item.weightGrams! / 1000),
      );

  double get _total {
    final discount = double.tryParse(_discount.text.trim()) ?? 0;
    return (_subtotal - discount).clamp(0, double.infinity).toDouble();
  }

  Future<void> _searchProducts(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final products = await widget.api.searchPosProducts(query);
      if (mounted) {
        setState(() {
          _matches = products;
          _searching = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _searching = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_searchProducts(value.trim()));
    });
  }

  Future<void> _submitBarcode(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final products = await widget.api.searchPosProducts(barcode);
      final normalized = barcode.toLowerCase();
      final exact = products.where((product) =>
          product.barcode?.toLowerCase() == normalized ||
          product.sku.toLowerCase() == normalized ||
          product.id.toLowerCase() == normalized);
      if (exact.isEmpty) {
        if (mounted) {
          setState(() {
            _matches = products;
            _searching = false;
            _error = 'No product exactly matches barcode "$barcode".';
          });
        }
        return;
      }
      final product = exact.first;
      await _addProduct(product);
      if (!mounted) return;
      setState(() {
        _matches = products;
        _searching = false;
      });
      _search.clear();
      _searchFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _searching = false;
      });
    }
  }

  Future<void> _addProduct(PosProduct product) async {
    if (_isWeightProduct(product)) {
      final grams = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text('Weight for ${product.name}'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight in grams'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value <= 0) return;
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
      if (grams == null || !mounted) return;
      setState(() => _cart.add(_PosCartLine(product, weightGrams: grams)));
      return;
    }
    final existing = _cart.where((item) => item.product.id == product.id);
    if (existing.isNotEmpty) {
      setState(() => existing.first.quantity++);
    } else {
      setState(() => _cart.add(_PosCartLine(product)));
    }
  }

  Future<void> _scan() async {
    final product = await widget.onScan();
    if (product != null && mounted) await _addProduct(product);
  }

  List<Map<String, dynamic>> _requestItems() => _cart
      .map((line) => {
            'productId': line.product.id,
            'quantity': line.quantity,
            'weightGrams': line.weightGrams,
          })
      .toList(growable: false);

  Future<void> _hold() async {
    if (_cart.isEmpty) {
      setState(() => _error = 'Add at least one product to hold a bill.');
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
                  'price': line.product.price,
                  'unitLabel': line.product.unitLabel,
                })
            .toList(growable: false),
        customerName: _customerName.text.trim().isEmpty
            ? null
            : _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim().isEmpty
            ? null
            : _customerPhone.text.trim(),
      );
      if (mounted) Navigator.pop(context);
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
    if (_cart.isEmpty) {
      setState(() => _error = 'Add products before completing the bill.');
      return;
    }
    final discount = double.tryParse(_discount.text.trim());
    if (discount == null || discount < 0 || discount > _subtotal) {
      setState(() =>
          _error = 'Enter a valid discount not greater than the subtotal.');
      return;
    }
    if (_paymentMethod == 'PENDING' &&
        (_customerName.text.trim().isEmpty ||
            _customerPhone.text.trim().isEmpty)) {
      setState(() =>
          _error = 'Enter the customer name and phone for a pending balance.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final sale = await widget.api.createPosSale(
        idempotencyKey: _idempotencyKey,
        items: _requestItems(),
        discount: discount,
        paymentMethod: _paymentMethod,
        customerName: _customerName.text.trim().isEmpty
            ? null
            : _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim().isEmpty
            ? null
            : _customerPhone.text.trim(),
        heldSaleId: widget.heldSale?.id,
      );
      if (mounted) Navigator.pop(context, sale);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
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
            maxWidth: isDesktop ? 1240 : 760,
            maxHeight: isDesktop ? 900 : 820,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildSearchField(isDesktop: true),
                      if (_error != null) _buildErrorMessage(),
                      const SizedBox(height: 8),
                      Expanded(child: _buildMatches()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 28),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(child: _buildCart()),
                      _buildCheckoutControls(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        _buildCheckoutControls(),
      ],
    );
  }

  Widget _buildDialogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.heldSale == null ? 'New bill' : 'Resume held bill',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.windows)
            Text(
              'F2 Search · F8 Complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          IconButton(
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
      decoration: InputDecoration(
        labelText: isDesktop
            ? 'Scan barcode or search product / SKU'
            : 'Search product, SKU or barcode',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: isDesktop
            ? null
            : IconButton(
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
            const Icon(Icons.error_outline_rounded,
                color: AppColors.errorText, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.errorText),
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
        child: Text(
          _search.text.isEmpty
              ? 'Search or scan to add products.'
              : 'No matching products.',
        ),
      );
    }
    return ListView.builder(
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final product = _matches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppRowCard(
            title: product.name,
            subtitle: '${product.sku} · ${_money(product.price)} · '
                '${product.available} ${product.unitLabel}',
            leading: product.imageUrl?.isNotEmpty == true
                ? ProductThumbnail(
                    imageUrl: product.imageUrl!,
                    size: 54,
                    width: 54,
                    height: 54,
                    backgroundColor: AppColors.thumbnailGreen,
                    borderRadius: BorderRadius.circular(AppRadii.thumbnail),
                  )
                : Text(
                    product.name.isEmpty ? '?' : product.name.substring(0, 1),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
            tint: AppColors.thumbnailGreen,
            trailing: IconButton(
              tooltip: 'Add ${product.name}',
              onPressed:
                  product.available <= 0 ? null : () => _addProduct(product),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCart() {
    if (_cart.isEmpty) return const Center(child: Text('Bill is empty.'));
    return ListView.separated(
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = _cart[index];
        final total = line.product.price *
            (line.weightGrams == null
                ? line.quantity
                : line.weightGrams! / 1000);
        return ListTile(
          title: Text(line.product.name),
          subtitle: Text(line.weightGrams == null
              ? 'Qty ${line.quantity}'
              : '${line.weightGrams} g'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (line.weightGrams == null) ...[
                IconButton(
                  tooltip: 'Decrease quantity',
                  onPressed: () => setState(() {
                    if (line.quantity > 1) {
                      line.quantity--;
                    } else {
                      _cart.removeAt(index);
                    }
                  }),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${line.quantity}'),
                IconButton(
                  tooltip: 'Increase quantity',
                  onPressed: () => setState(() => line.quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              const SizedBox(width: 8),
              Text(_money(total)),
              IconButton(
                tooltip: 'Remove item',
                onPressed: () => setState(() => _cart.removeAt(index)),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
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
                  decoration: InputDecoration(
                    labelText: _paymentMethod == 'PENDING'
                        ? 'Customer name *'
                        : 'Customer (optional)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customerPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _paymentMethod == 'PENDING'
                        ? 'Customer phone *'
                        : 'Customer phone',
                    isDense: true,
                  ),
                ),
              ),
            ],
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
                  decoration: const InputDecoration(
                    labelText: 'Discount amount',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'DIGITAL',
                      child: Text('PhonePe / UPI'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  ],
                  onChanged: (value) => setState(() {
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
              Text('Subtotal ${_money(_subtotal)}'),
              Text(
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
                label: const Text('Hold'),
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
                label: const Text('Complete bill'),
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

class _PosCartLine {
  _PosCartLine(
    this.product, {
    this.quantity = 1,
    this.weightGrams,
  });

  final PosProduct product;
  int quantity;
  final int? weightGrams;
}
