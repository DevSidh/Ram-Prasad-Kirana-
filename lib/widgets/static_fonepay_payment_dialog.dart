import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/manual_fonepay_verification.dart';
import '../models/pos_models.dart';

class StaticFonepayPaymentDialog extends StatefulWidget {
  const StaticFonepayPaymentDialog(
      {super.key,
      required this.amount,
      required this.cashierId,
      required this.qrAsset,
      this.confirmationReference,
      this.paymentMethod = 'FONEPAY',
      this.providerName = 'Fonepay',
      required this.onVerified,
      required this.onPrint});
  final double amount;
  final String cashierId;
  final String qrAsset;
  final String? confirmationReference;
  final String paymentMethod;
  final String providerName;
  final Future<PosSale> Function(ManualFonepayVerification) onVerified;
  final Future<bool> Function(PosSale) onPrint;

  @override
  State<StaticFonepayPaymentDialog> createState() =>
      _StaticFonepayPaymentDialogState();
}

class _StaticFonepayPaymentDialogState
    extends State<StaticFonepayPaymentDialog> {
  late final String _confirmationReference =
      widget.confirmationReference ?? 'CASHIER-${const Uuid().v4()}';
  bool _checked = false;
  bool _busy = false;
  bool _qrStarted = false;
  bool _qrReady = false;
  bool _printed = false;
  PosSale? _sale;
  String? _error;
  String? _qrError;
  ManualFonepayVerification? _verification;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_qrStarted) return;
    _qrStarted = true;
    if (widget.qrAsset.isEmpty) {
      _qrError =
          'The business Fonepay QR has not been configured. Ask the administrator to add the approved QR image.';
      return;
    }
    var failed = false;
    precacheImage(AssetImage(widget.qrAsset), context, onError: (error, stack) {
      failed = true;
    }).then((_) {
      if (!mounted) return;
      setState(() {
        _qrReady = !failed;
        if (failed) {
          _qrError =
              'The business QR could not be loaded. Payment confirmation is disabled.';
        }
      });
    });
  }

  void _close() {
    if (!_busy) Navigator.pop(context, _sale?.withAutoPrintAllowed(false));
  }

  Future<void> _confirm() async {
    if (_busy ||
        _sale != null ||
        !_qrReady ||
        !_checked ||
        widget.cashierId.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _verification ??= ManualFonepayVerification(
        provider: widget.paymentMethod,
        transactionReference: _confirmationReference,
        verifiedAt: DateTime.now(),
        cashierId: widget.cashierId);
    try {
      final sale = await widget.onVerified(_verification!);
      if (!mounted) return;
      if (sale.paymentMethod != widget.paymentMethod ||
          sale.paymentStatus != 'COMPLETED' ||
          (sale.total * 100).round() != (widget.amount * 100).round()) {
        throw StateError(
            'The saved bill does not match this payment. Keep the reference and contact the administrator.');
      }
      setState(() => _sale = sale);
      if (sale.autoPrintAllowed) await _printSavedBill();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Could not save the bill: $error. Retry this checkout; your payment confirmation is retained.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printSavedBill() async {
    final sale = _sale;
    if (sale == null) return;
    try {
      final printed = await widget.onPrint(sale);
      if (!mounted) return;
      setState(() {
        _printed = printed;
        _error = printed
            ? null
            : 'The bill is saved, but printing was cancelled or failed. Reprint the same bill below.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Bill ${sale.receiptNumber} is saved. Printing failed: $error');
      }
    }
  }

  Future<void> _reprint() async {
    if (_busy || _sale == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _printSavedBill();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _sale != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
        canPop: !_busy && !paid,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CHECKOUT · PAYMENT REVIEW',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Text('Pay with ${widget.providerName}'),
              ],
            )),
            IconButton(
                tooltip: 'Close payment dialog',
                onPressed: _busy ? null : _close,
                icon: const Icon(Icons.close))
          ]),
          content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child:
                        Text('Scan the QR and enter the exact bill amount.')),
                const SizedBox(height: 24),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      Text('Total payable · NPR',
                          style: theme.textTheme.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                          color: colors.surfaceContainerHighest,
                        ),
                        child: Text(widget.amount.toStringAsFixed(2),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                if (paid) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 72),
                  const Text('Payment received - confirmed by cashier'),
                  Text('Bill ${_sale!.invoiceNumber ?? _sale!.receiptNumber}',
                      textAlign: TextAlign.center),
                  Text(_printed
                      ? 'Bill sent to printer.'
                      : 'The paid bill is saved. You can reprint it without charging again.'),
                ] else ...[
                  if (_qrError != null)
                    Text(_qrError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))
                  else if (!_qrReady)
                    const CircularProgressIndicator()
                  else
                    Container(
                        width: 320,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('Ram Prasad General Store',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Image.asset(widget.qrAsset,
                              width: 320,
                              height: (MediaQuery.sizeOf(context).height * 0.42)
                                  .clamp(200.0, 380.0),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              semanticLabel:
                                  'Business static ${widget.providerName} QR'),
                          const SizedBox(height: 12),
                          Text('${widget.providerName} · Scan to pay',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: Colors.black54)),
                        ])),
                  const SizedBox(height: 12),
                  Text(
                      'Scan using ${widget.providerName} and enter the exact amount.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Waiting for cashier to confirm payment received.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text(
                        'Tick the box below to confirm you received the displayed amount. No automatic payment check is performed.'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                          'I received the full payment of this bill.'),
                      value: _checked,
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _checked = value ?? false)),
                  if (widget.cashierId.isEmpty)
                    Text(
                        'Sign in with a cashier account to confirm this payment.',
                        style: TextStyle(color: colors.error)),
                ],
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator()),
              ]))),
          actions: [
            TextButton(
                onPressed: _busy ? null : _close,
                child: Text(paid ? 'Done' : 'Cancel / Back')),
            if (paid)
              FilledButton.icon(
                  onPressed: _busy ? null : _reprint,
                  icon: const Icon(Icons.print),
                  label: const Text('Reprint Bill'))
            else
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _busy ||
                              !_qrReady ||
                              !_checked ||
                              widget.cashierId.isEmpty
                          ? null
                          : _confirm,
                      child: Text(
                          _busy
                              ? 'Saving bill…'
                              : 'Payment Verified — Create & Print Bill',
                          textAlign: TextAlign.center))),
          ],
        ));
  }
}
