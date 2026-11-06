import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/pos_models.dart';
import '../../models/room_inventory.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/offline_pos_store.dart';
import '../../services/room_inventory_service.dart';
import '../../widgets/billing_localized_widgets.dart';
import '../../core/billing_strings.dart';

class AdminRoomInventoryScreen extends StatefulWidget {
  const AdminRoomInventoryScreen(
      {super.key,
      required this.api,
      this.offlineStore = const OfflinePosStore(),
      this.readOnly = false});
  final ApiService api;
  final OfflinePosStore offlineStore;
  final bool readOnly;
  @override
  State<AdminRoomInventoryScreen> createState() =>
      _AdminRoomInventoryScreenState();
}

class _AdminRoomInventoryScreenState extends State<AdminRoomInventoryScreen> {
  late final _api =
      AdminApiService(widget.api, offlineStore: widget.offlineStore);
  late final _service = RoomInventoryService(_api, widget.offlineStore);
  RoomInventorySnapshot? _snapshot;
  List<PosProduct> _products = [];
  String? _error, _roomId;
  String _search = '';
  bool _allRooms = true, _loading = true;
  int _request = 0, _page = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_loading) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.load();
      final catalog = snapshot.products.toList();
      if (!mounted || request != _request) return;
      catalog
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _snapshot = snapshot;
        _products = catalog;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _rooms() async {
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const BillingText('Rooms'),
              content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final room in _snapshot!.rooms)
                      ListTile(
                        title: Text(room.label),
                        subtitle:
                            BillingText(room.active ? 'Active' : 'Inactive'),
                        trailing: IconButton(
                            tooltip: BillingStrings.tr('Edit room'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              Navigator.pop(context);
                              unawaited(_editRoom(room));
                            }),
                      ),
                    if (_snapshot!.rooms.isEmpty)
                      const BillingText('No rooms yet. Add your first room.'),
                  ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const BillingText('Close')),
                FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      unawaited(_editRoom(null));
                    },
                    icon: const Icon(Icons.add),
                    label: const BillingText('Add room'))
              ],
            ));
  }

  Future<void> _editRoom(InventoryRoom? room) async {
    final name = TextEditingController(text: room?.name ?? '');
    final number = TextEditingController(text: room?.number ?? '');
    var active = room?.active ?? true, busy = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: BillingText(room == null ? 'Add room' : 'Edit room'),
                    content: SizedBox(
                        width: 460,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              BillingTextFormField(
                                  controller: name,
                                  enabled: !busy,
                                  decoration: const BillingInputDecoration(
                                      labelText: 'Room name',
                                      hintText: 'For example: Main store'),
                                  maxLength: 80),
                              const SizedBox(height: 16),
                              BillingTextFormField(
                                  controller: number,
                                  enabled: !busy,
                                  decoration: const BillingInputDecoration(
                                      labelText: 'Room number',
                                      hintText: 'For example: 01'),
                                  maxLength: 30),
                              if (room != null)
                                SwitchListTile(
                                    title: const BillingText('Active'),
                                    value: active,
                                    onChanged: busy
                                        ? null
                                        : (v) => update(() => active = v)),
                              if (error != null)
                                BillingText(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
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
                                    await _api.saveInventoryRoom(
                                        id: room?.id,
                                        name: name.text.trim(),
                                        number: number.text.trim(),
                                        active: active);
                                    if (context.mounted) Navigator.pop(context);
                                    if (mounted) await _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: BillingText(busy ? 'Saving...' : 'Save'))
                    ],
                  ),
                )));
    // Dialog route transitions may still render the text fields for one frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    number.dispose();
  }

  Future<void> _transfer(PosProduct product) async {
    final snapshot = _snapshot!;
    final locations = snapshot.locations;
    if (locations.length < 2) {
      await _rooms();
      return;
    }
    String? from = _allRooms ? null : _roomId;
    String? to = locations.firstWhere((id) => id != from);
    final quantity = TextEditingController();
    final requestId = const Uuid().v4();
    var busy = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(builder: (context, update) {
              Widget dropdown(String label, String? value,
                      ValueChanged<String?> changed) =>
                  DropdownButtonFormField<String>(
                    key: ValueKey('$label/$value'),
                    initialValue: value ?? '',
                    isExpanded: true,
                    decoration: BillingInputDecoration(labelText: label),
                    items: [
                      for (final id in locations)
                        DropdownMenuItem(
                            value: id ?? '',
                            child: BillingText(snapshot.roomLabel(id)))
                    ],
                    onChanged: busy ? null : (v) => changed(v == '' ? null : v),
                  );
              return PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: const BillingText('Move stock between rooms'),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(product.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              const BillingText(
                                  'Moving stock changes its location, not the total stock.'),
                              const SizedBox(height: 16),
                              dropdown('Take from', from,
                                  (v) => update(() => from = v)),
                              const SizedBox(height: 16),
                              dropdown(
                                  'Move to', to, (v) => update(() => to = v)),
                              const SizedBox(height: 16),
                              BillingText(
                                  'Available here: ${snapshot.quantity(product.id, from)} ${roomStockUnit(product)}'),
                              BillingTextFormField(
                                  controller: quantity,
                                  enabled: !busy,
                                  keyboardType: TextInputType.number,
                                  decoration: BillingInputDecoration(
                                      labelText: 'Quantity',
                                      suffixText: roomStockUnit(product))),
                              if (error != null)
                                BillingText(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const BillingText('Cancel')),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final count =
                                      int.tryParse(quantity.text.trim());
                                  if (count == null ||
                                      count <= 0 ||
                                      from == to ||
                                      count >
                                          snapshot.quantity(product.id, from)) {
                                    update(() => error =
                                        'Choose different rooms and an available whole quantity.');
                                    return;
                                  }
                                  update(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    await _api.transferRoomStock({
                                      'requestId': requestId,
                                      'productId': product.id,
                                      'fromRoomId': from,
                                      'toRoomId': to,
                                      'quantity': count
                                    });
                                    if (context.mounted) Navigator.pop(context);
                                    if (mounted) await _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: BillingText(busy ? 'Saving...' : 'Move stock'))
                    ],
                  ));
            }));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    quantity.dispose();
  }

  Future<void> _history(PosProduct product) async {
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(product.name),
              content: SizedBox(
                  width: 600,
                  height: 420,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _api.getRoomMovements(product.id),
                      builder: (context, state) {
                        if (state.hasError) {
                          return BillingText(state.error.toString());
                        }
                        if (!state.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (state.data!.isEmpty) {
                          return const BillingText('No room movements yet.');
                        }
                        return ListView(children: [
                          for (final row in state.data!)
                            ListTile(
                              title: BillingText(
                                  '${row['quantity']} ${roomStockUnit(product)} · ${_snapshot!.roomLabel(row['fromRoomId'] as String?)} → ${row['reason'] == 'TRANSFER' ? _snapshot!.roomLabel(row['toRoomId'] as String?) : BillingStrings.tr(row['reason'] as String)}'),
                              subtitle: Text(
                                  '${row['createdAt']}\n${row['referenceId'] ?? ''}'),
                              isThreeLine: true,
                            )
                        ]);
                      })),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const BillingText('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final query = _search.trim().toLowerCase();
    final filtered = _products
        .where((p) =>
            '${p.name} ${p.sku} ${p.barcode ?? ''}'
                .toLowerCase()
                .contains(query) &&
            (_allRooms || (snapshot?.quantity(p.id, _roomId) ?? 0) > 0))
        .toList();
    final pages = (filtered.length / 40).ceil();
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final counts = <String, int>{};
    if (snapshot != null) {
      for (final product in filtered) {
        final quantity = _allRooms
            ? snapshot.totals[product.id]?.total ?? 0
            : snapshot.quantity(product.id, _roomId);
        final unit = roomStockUnit(product);
        counts[unit] = (counts[unit] ?? 0) + quantity;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const BillingText('Inventory')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Column(children: [
          if (_loading) const LinearProgressIndicator(),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!widget.readOnly)
                            FilledButton.icon(
                                onPressed: snapshot == null ||
                                        snapshot.isCached ||
                                        _loading
                                    ? null
                                    : _rooms,
                                icon: const Icon(Icons.meeting_room_outlined),
                                label: const BillingText('Manage rooms')),
                          OutlinedButton.icon(
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh),
                              label: const BillingText('Refresh')),
                          BillingText('${filtered.length} products'),
                          for (final entry in counts.entries)
                            Text('${entry.value} ${entry.key}',
                                style: Theme.of(context).textTheme.titleMedium),
                        ]),
                    const SizedBox(height: 12),
                    const ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: BillingText('Room stock help'),
                        children: [
                          Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: BillingText(
                                  'Assign existing stock to rooms. New stock and returns enter Unassigned. Loose goods use grams; packs remain whole packs.')),
                        ]),
                    if (snapshot?.isCached == true)
                      const BillingText(
                          'Offline room snapshot. Transfers require an internet connection.'),
                    if (snapshot?.conflictedProducts.isNotEmpty == true)
                      const BillingText(
                          'Local room stock conflicts with server stock. Review the stock synchronization conflict before billing this product.'),
                    if (_error != null)
                      BillingText(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                    BillingTextFormField(
                        decoration: const BillingInputDecoration(
                            labelText: 'Search product, SKU or barcode',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() {
                              _search = v;
                              _page = 0;
                            })),
                    const SizedBox(height: 12),
                    if (snapshot != null)
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    label: const BillingText('All rooms'),
                                    selected: _allRooms,
                                    onSelected: (_) => setState(() {
                                          _allRooms = true;
                                          _page = 0;
                                        }))),
                            for (final id in snapshot.locations)
                              Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                      label:
                                          BillingText(snapshot.roomLabel(id)),
                                      selected: !_allRooms && _roomId == id,
                                      onSelected: (_) => setState(() {
                                            _allRooms = false;
                                            _roomId = id;
                                            _page = 0;
                                          }))),
                          ])),
                  ])),
        ])),
        if (snapshot == null)
          SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: BillingText(_loading
                      ? 'Loading inventory...'
                      : 'Inventory could not be loaded. Please retry.')))
        else if (filtered.isEmpty)
          const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: BillingText('No products in this view.')))
        else
          SliverList.builder(
              itemCount: filtered.skip(page * 40).take(40).length,
              itemBuilder: (context, index) {
                final product = filtered[page * 40 + index];
                return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text(product.sku),
                              const SizedBox(height: 8),
                              Wrap(spacing: 12, runSpacing: 8, children: [
                                for (final id in snapshot.locations.where(
                                    (id) =>
                                        snapshot.quantity(product.id, id) > 0 ||
                                        id == null))
                                  Chip(
                                      label: BillingText(
                                          '${snapshot.roomLabel(id)}: ${snapshot.quantity(product.id, id)} ${roomStockUnit(product)}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis)),
                              ]),
                              Wrap(spacing: 8, children: [
                                if (!widget.readOnly)
                                  OutlinedButton.icon(
                                      onPressed: snapshot.isCached || _loading
                                          ? null
                                          : () => _transfer(product),
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const BillingText(
                                          'Place / move stock')),
                                TextButton.icon(
                                    onPressed: () => _history(product),
                                    icon: const Icon(Icons.history),
                                    label:
                                        const BillingText('Movement history')),
                              ]),
                            ])));
              }),
        if (pages > 1)
          SliverToBoxAdapter(
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed:
                    page > 0 ? () => setState(() => _page = page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            BillingText('Page ${page + 1} of $pages'),
            IconButton(
                onPressed: page + 1 < pages
                    ? () => setState(() => _page = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right)),
          ])),
      ]),
    );
  }
}
