import 'billing_localized_widgets.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pos_models.dart';
import '../models/fonepay_payment_request.dart';
import '../services/fonepay_api_service.dart';
import '../services/pos_receipt_service.dart';
import '../services/api_service.dart';

class FonepayPaymentDialog extends StatefulWidget {
  const FonepayPaymentDialog(
      {super.key,
      required this.sale,
      required this.api,
      this.finalizeCheckout = false});
  final PosSale sale;
  final FonepayApiService api;
  final bool finalizeCheckout;
  @override
  State<FonepayPaymentDialog> createState() => _FonepayPaymentDialogState();
}

class _FonepayPaymentDialogState extends State<FonepayPaymentDialog> {
  FonepayPaymentRequest? _request;
  bool _busy = true;
  String? _error;
  Timer? _expiry;
  Timer? _polling;
  bool _finishing = false;
  bool _closed = false;
  String get _key => 'fonepay_request_${widget.sale.id}';
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _polling?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final config = await widget.api.configuration();
      if (config['enabled'] != true) {
        throw ApiResponseException(config['message'] as String? ??
            'Fonepay merchant integration is not activated.');
      }
      final preferences = await SharedPreferences.getInstance();
      final id = preferences.getString(_key);
      FonepayPaymentRequest? request;
      if (id != null) {
        try {
          request = await widget.api.get(id);
        } on ApiResponseException catch (error) {
          if (error.statusCode != 404) rethrow;
          await preferences.remove(_key);
        }
      }
      request ??= await widget.api.create(widget.sale.id);
      await preferences.setString(_key, request.id);
      if (!mounted) return;
      _setRequest(request);
      final seconds = config['pollIntervalSeconds'];
      if (seconds is int && seconds >= 5 && seconds <= 120) {
        _polling?.cancel();
        _polling = Timer.periodic(Duration(seconds: seconds), (_) {
          final current = _request;
          if (!_busy &&
              !_finishing &&
              !_closed &&
              current != null &&
              ['READY', 'PENDING', 'UNKNOWN', 'CREATING']
                  .contains(current.state)) {
            unawaited(_action(() => widget.api.verify(current.id)));
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setRequest(FonepayPaymentRequest request) {
    _expiry?.cancel();
    setState(() => _request = request);
    if (widget.finalizeCheckout &&
        !request.isTest &&
        ['VERIFIED', 'PAID'].contains(request.state)) {
      unawaited(_finalize(request));
    }
    final remaining = request.expiresAt?.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      _expiry = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _finalize(FonepayPaymentRequest request) async {
    if (_finishing || _closed || !mounted) return;
    _finishing = true;
    _polling?.cancel();
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || _closed) return;
    try {
      final sale = await widget.api.finalize(request.id);
      if (!mounted || _closed) return;
      final printAllowed = await widget.api.claimAutoPrint(request.id);
      if (mounted && !_closed) {
        Navigator.pop(context, FonepayCheckoutCompletion(sale, printAllowed));
      }
    } catch (error) {
      if (mounted && !_closed) {
        setState(() {
          _error =
              'Payment is retained. Finalization or print preparation failed: $error';
          _finishing = false;
        });
      }
    }
  }

  void _close() {
    if (_finishing) return;
    _closed = true;
    _polling?.cancel();
    Navigator.pop(
        context, widget.finalizeCheckout ? null : _request?.paid == true);
  }

  Future<void> _action(Future<FonepayPaymentRequest> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await work();
      if (mounted) _setRequest(result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print({bool thermal = false}) async {
    final request = _request;
    if (_busy || request == null) return;
    setState(() => _busy = true);
    try {
      final bytes = thermal
          ? await PosReceiptService.createPdf(widget.sale,
              paperWidthMm: 80, fonepay: request)
          : await PosReceiptService.createInvoicePdf(widget.sale,
              fonepay: request);
      await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name:
              'Fonepay-${widget.sale.invoiceNumber ?? widget.sale.receiptNumber}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final payable = request?.matchesPayableBill(widget.sale) == true;
    return PopScope(
        canPop: false,
        child: AlertDialog(
            title: Row(children: [
              const Expanded(child: BillingText('Pay with Fonepay')),
              BillingIconButton(
                  tooltip: 'Close payment',
                  onPressed: _finishing ? null : _close,
                  icon: const Icon(Icons.close))
            ]),
            content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BillingText(
                        'Bill ${widget.sale.invoiceNumber ?? widget.sale.receiptNumber}'),
                    BillingText(
                        'Final total: NPR ${widget.sale.total.toStringAsFixed(2)}'),
                    if (request != null) ...[
                      if (!request.isTest &&
                          ['VERIFIED', 'PAID'].contains(request.state)) ...[
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 88),
                        const BillingText('Payment successful',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        if (_finishing)
                          const BillingText('Finalizing your bill…'),
                        if (!_finishing && widget.finalizeCheckout)
                          FilledButton(
                              onPressed: () => _finalize(request),
                              child:
                                  const BillingText('Retry bill finalization')),
                      ],
                      if (request.isTest)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: BillingText(
                                    'SANDBOX TEST — cannot pay or settle a real bill.'))),
                      BillingText(request.merchantName ??
                          'Merchant verification pending'),
                      BillingText('Payable: NPR ${request.amount}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      SelectableText('Reference: ${request.reference}'),
                      BillingText(
                          'Status: ${request.paid ? 'Payment verified by backend' : request.state}'),
                      if (payable)
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: QrImageView(
                                data: request.qrPayload!,
                                size: 240,
                                backgroundColor: Colors.white,
                                semanticsLabel:
                                    'Fonepay QR for NPR ${request.amount}')),
                      if (payable)
                        const BillingText('Scan to pay with Fonepay'),
                      if (payable) const BillingText('Waiting for payment…'),
                      if (!payable && !request.paid)
                        const BillingText(
                            'This QR is not currently payable. Verify or reconcile this reference before requesting another.'),
                      if (request.failureCode != null)
                        BillingText('Review: ${request.failureCode}'),
                      if (!request.paid &&
                          request.state != 'VERIFIED' &&
                          request.expiresAt != null &&
                          !request.expiresAt!.isAfter(DateTime.now()))
                        const BillingText(
                            'QR expired. Verify or cancel this reference before retrying.'),
                    ],
                    if (_busy)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator()),
                    if (_error != null)
                      SelectableText(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (!_busy && request == null)
                      TextButton(
                          onPressed: () {
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            unawaited(_open());
                          },
                          child: const BillingText('Retry connection')),
                    if (!_busy &&
                        !_finishing &&
                        request != null &&
                        !request.paid &&
                        request.state != 'VERIFIED')
                      Wrap(spacing: 8, children: [
                        FilledButton(
                            onPressed: () =>
                                _action(() => widget.api.verify(request.id)),
                            child: const BillingText('Verify with Fonepay')),
                        TextButton(
                            onPressed: () =>
                                _action(() => widget.api.cancel(request.id)),
                            child: const BillingText('Cancel with provider')),
                        if (['FAILED', 'EXPIRED', 'CANCELLED', 'TEST_VERIFIED']
                            .contains(request.state))
                          TextButton(
                              onPressed: () => _action(() async {
                                    final next =
                                        await widget.api.create(widget.sale.id);
                                    final preferences =
                                        await SharedPreferences.getInstance();
                                    await preferences.setString(_key, next.id);
                                    return next;
                                  }),
                              child: const BillingText('Request fresh QR')),
                      ]),
                    if (!_busy && payable && !widget.finalizeCheckout)
                      Wrap(children: [
                        TextButton(
                            onPressed: _print,
                            child: const BillingText('Print/PDF with QR')),
                        TextButton(
                            onPressed: () => _print(thermal: true),
                            child: const BillingText('80 mm receipt with QR')),
                      ]),
                  ],
                ))),
            actions: [
              TextButton(
                  onPressed: _finishing ? null : _close,
                  child: const BillingText('Close'))
            ]));
  }
}

class FonepayCheckoutCompletion {
  const FonepayCheckoutCompletion(this.sale, this.autoPrintAllowed);
  final PosSale sale;
  final bool autoPrintAllowed;
}
