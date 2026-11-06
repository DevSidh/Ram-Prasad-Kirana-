import 'package:flutter/material.dart';
import '../models/room_inventory.dart';
import '../services/admin_api_service.dart';
import '../services/room_inventory_service.dart';
import 'billing_localized_widgets.dart';

/// Quantities use the same units as the opening stock field (kg for loose goods).
class InitialRoomAllocationField extends StatefulWidget {
  const InitialRoomAllocationField(
      {super.key,
      required this.api,
      required this.stock,
      this.enabled = true,
      this.wholeUnits = true});
  final AdminApiService api;
  final TextEditingController stock;
  final bool enabled, wholeUnits;
  @override
  State<InitialRoomAllocationField> createState() =>
      InitialRoomAllocationFieldState();
}

class InitialRoomAllocationFieldState
    extends State<InitialRoomAllocationField> {
  List<InventoryRoom> _rooms = [];
  final _rows = <({String? roomId, String quantity, int key})>[];
  bool _loading = true;
  String? _error;
  int _nextKey = 0;
  late String _previousStock;
  double get _total => double.tryParse(widget.stock.text.trim()) ?? 0;
  List<Map<String, dynamic>>? get allocations => _total <= 0
      ? null
      : [
          for (final row in _rows)
            {
              'roomId': row.roomId,
              'quantity': double.parse(row.quantity.trim())
            }
        ];
  @override
  void initState() {
    super.initState();
    _previousStock = widget.stock.text;
    _rows.add((roomId: null, quantity: widget.stock.text, key: _nextKey++));
    widget.stock.addListener(_stockChanged);
    _load();
  }

  void _stockChanged() {
    if (!mounted) return;
    setState(() {
      if (_rows.length == 1 && _rows.single.quantity == _previousStock) {
        _rows[0] = (
          roomId: _rows.single.roomId,
          quantity: widget.stock.text,
          key: _nextKey++
        );
      }
      _previousStock = widget.stock.text;
    });
  }

  @override
  void dispose() {
    widget.stock.removeListener(_stockChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot =
          await RoomInventoryService(widget.api, widget.api.offlineStore)
              .load();
      if (mounted) {
        setState(() {
          _rooms = snapshot.rooms.where((r) => r.active).toList();
          for (var i = 0; i < _rows.length; i++) {
            final row = _rows[i];
            if (row.roomId != null && !_rooms.any((r) => r.id == row.roomId)) {
              _rows[i] =
                  (roomId: null, quantity: row.quantity, key: _nextKey++);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to load rooms. Retry or open Inventory to add a room.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool validate() {
    if (_total <= 0) return true;
    String? error;
    final seen = <String>{};
    var sum = 0.0;
    for (final row in _rows) {
      final n = double.tryParse(row.quantity.trim());
      if (row.roomId == null ||
          !_rooms.any((r) => r.id == row.roomId) ||
          !seen.add(row.roomId!)) {
        error = 'Choose each room once using its name or number.';
      }
      if (n == null ||
          !n.isFinite ||
          n <= 0 ||
          (widget.wholeUnits
              ? n != n.roundToDouble()
              : (n * 1000 - (n * 1000).round()).abs() > 0.000001)) {
        error =
            'Enter valid room quantities in the same unit as starting stock.';
      }
      sum += n ?? 0;
    }
    if (_rows.isEmpty || (sum - _total).abs() > 0.000001) {
      error = 'Room quantities must match the starting stock exactly.';
    }
    if (_loading) error = 'Wait for the room list to load.';
    setState(() => _error = error);
    return error == null;
  }

  Future<void> _addRoom() async {
    final name = TextEditingController(), number = TextEditingController();
    var busy = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                      title: const BillingText('Add room'),
                      content: SizedBox(
                          width: 400,
                          child: SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                BillingTextFormField(
                                    controller: name,
                                    enabled: !busy,
                                    maxLength: 80,
                                    decoration: const BillingInputDecoration(
                                        labelText: 'Room name')),
                                BillingTextFormField(
                                    controller: number,
                                    enabled: !busy,
                                    maxLength: 30,
                                    decoration: const BillingInputDecoration(
                                        labelText: 'Room number')),
                                if (error != null)
                                  BillingText(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                              ]))),
                      actions: [
                        TextButton(
                            onPressed:
                                busy ? null : () => Navigator.pop(context),
                            child: const BillingText('Cancel')),
                        FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (name.text.trim().isEmpty ||
                                        number.text.trim().isEmpty) {
                                      update(() => error =
                                          'Enter a room name and a unique room number.');
                                      return;
                                    }
                                    update(() {
                                      busy = true;
                                      error = null;
                                    });
                                    try {
                                      await widget.api.saveInventoryRoom(
                                          name: name.text.trim(),
                                          number: number.text.trim(),
                                          active: true);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      await _load();
                                    } catch (e) {
                                      if (context.mounted) {
                                        update(() {
                                          busy = false;
                                          error = e.toString();
                                        });
                                      }
                                    }
                                  },
                            child: BillingText(busy ? 'Saving...' : 'Save')),
                      ]),
                )));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    number.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BillingText('Starting stock by room'),
            const BillingText(
                'Split the starting stock between rooms. Use the same stock units as above.'),
            if (_loading) const LinearProgressIndicator(),
            if (_total > 0) ...[
              for (var i = 0; i < _rows.length; i++)
                Padding(
                    key: ValueKey(_rows[i].key),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue:
                                  _rooms.any((r) => r.id == _rows[i].roomId)
                                      ? _rows[i].roomId
                                      : null,
                              decoration: const BillingInputDecoration(
                                  labelText: 'Room name / number'),
                              items: _rooms
                                  .map((r) => DropdownMenuItem(
                                      value: r.id, child: Text(r.label)))
                                  .toList(),
                              onChanged: !widget.enabled || _loading
                                  ? null
                                  : (id) => setState(() => _rows[i] = (
                                        roomId: id,
                                        quantity: _rows[i].quantity,
                                        key: _rows[i].key
                                      ))),
                          Row(children: [
                            Expanded(
                                child: BillingTextFormField(
                                    initialValue: _rows[i].quantity,
                                    enabled: widget.enabled,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const BillingInputDecoration(
                                        labelText: 'Quantity in this room'),
                                    onChanged: (value) => _rows[i] = (
                                          roomId: _rows[i].roomId,
                                          quantity: value,
                                          key: _rows[i].key
                                        ))),
                            BillingIconButton(
                                tooltip: 'Remove room allocation',
                                onPressed: !widget.enabled
                                    ? null
                                    : () => setState(() => _rows.removeAt(i)),
                                icon: const Icon(Icons.remove_circle_outline)),
                          ]),
                        ])),
              TextButton.icon(
                  onPressed: !widget.enabled
                      ? null
                      : () => setState(() => _rows
                          .add((roomId: null, quantity: '', key: _nextKey++))),
                  icon: const Icon(Icons.add),
                  label: const BillingText('Add another room')),
            ],
            Wrap(spacing: 16, children: [
              TextButton(
                  onPressed: widget.enabled && !_loading ? _load : null,
                  child: const BillingText('Refresh rooms')),
              TextButton(
                  onPressed: widget.enabled && !_loading ? _addRoom : null,
                  child: const BillingText('Add room')),
            ]),
            if (_error != null)
              BillingText(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ])));
}
