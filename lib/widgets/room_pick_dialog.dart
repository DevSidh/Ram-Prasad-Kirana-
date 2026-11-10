import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../models/room_inventory.dart';
import 'billing_localized_widgets.dart';
import 'product_thumbnail.dart';

/// Selection only: stock is deducted when the bill commits, never on Cancel.
class RoomPickDialog extends StatefulWidget {
  const RoomPickDialog(
      {super.key,
      required this.snapshot,
      required this.products,
      required this.requiredQuantities,
      this.initialPicks = const []});
  final RoomInventorySnapshot snapshot;
  final List<PosProduct> products;
  final Map<String, int> requiredQuantities;
  final List<RoomPick> initialPicks;
  @override
  State<RoomPickDialog> createState() => _RoomPickDialogState();
}

class _RoomPickDialogState extends State<RoomPickDialog> {
  final _controllers = <String, Map<String?, TextEditingController>>{};
  String? _error;

  /// A product with room allocations must be withdrawn from those rooms.
  /// Do not expose the calculated Unassigned bucket alongside an assigned
  /// room; doing so lets cashiers accidentally split a pick into a bucket that
  /// is not actually part of the inventory assignment.
  List<String?> _visibleLocations(String productId) {
    final assigned = widget.snapshot.locations
        .where(
            (id) => id != null && widget.snapshot.quantity(productId, id) > 0)
        .toList(growable: false);
    return assigned.isNotEmpty ? assigned : const <String?>[null];
  }

  @override
  void initState() {
    super.initState();
    for (final product in widget.products) {
      var left = widget.requiredQuantities[product.id]!;
      _controllers[product.id] = {};
      final selected = <String?, int>{};
      for (final pick
          in widget.initialPicks.where((p) => p.productId == product.id)) {
        if (!widget.snapshot.locations.contains(pick.roomId)) continue;
        final take = pick.quantity
            .clamp(0, widget.snapshot.available(product.id, pick.roomId))
            .clamp(0, left);
        selected[pick.roomId] = take;
        left -= take;
      }
      for (final id in _visibleLocations(product.id)) {
        final extra = left.clamp(
            0, widget.snapshot.available(product.id, id) - (selected[id] ?? 0));
        final take = (selected[id] ?? 0) + extra;
        left -= extra;
        _controllers[product.id]![id] =
            TextEditingController(text: take == 0 ? '' : '$take');
      }
    }
  }

  @override
  void dispose() {
    for (final values in _controllers.values) {
      for (final c in values.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _confirm() {
    try {
      final picks = <RoomPick>[];
      for (final entry in _controllers.entries) {
        for (final field in entry.value.entries) {
          final value = field.value.text.trim();
          final count = value.isEmpty ? 0 : int.tryParse(value);
          if (count == null || count < 0) {
            throw StateError('Enter a whole quantity of zero or more.');
          }
          if (count > 0) {
            picks.add(RoomPick(
                productId: entry.key, roomId: field.key, quantity: count));
          }
        }
      }
      widget.snapshot.validatePicks(picks, widget.requiredQuantities);
      Navigator.pop(context, picks);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const BillingText('Where should we take the products from?'),
        content: SizedBox(
            width: 680,
            height: MediaQuery.sizeOf(context).height * .58,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BillingText(
                  'Confirm the source room for every product. You can split a quantity between rooms.'),
              if (widget.snapshot.isCached)
                const BillingText(
                    'Offline estimate. Room stock will be checked again when this bill synchronizes.'),
              if (!widget.snapshot.configured)
                const BillingText(
                    'No rooms configured. Stock is currently Unassigned. Add rooms from Inventory.'),
              const SizedBox(height: 12),
              Expanded(
                  child: ListView(children: [
                for (final product in widget.products)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  ProductThumbnail(
                                      imageUrl: product.imageUrl ?? '',
                                      size: 56),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(product.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                ]),
                                BillingText(
                                    'Needed: ${widget.requiredQuantities[product.id]} ${roomStockUnit(product)}'),
                                for (final id in _visibleLocations(product.id))
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(children: [
                                        Expanded(
                                            child: BillingText(
                                                '${widget.snapshot.roomLabel(id)}\nAvailable: ${widget.snapshot.available(product.id, id)} ${roomStockUnit(product)}')),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                            width: 120,
                                            child: BillingTextFormField(
                                                controller: _controllers[
                                                    product.id]![id],
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const BillingInputDecoration(
                                                        labelText:
                                                            'Take quantity'))),
                                      ])),
                              ])))
              ])),
              if (_error != null)
                BillingText(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const BillingText('Cancel / Back')),
          FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const BillingText('Use these rooms'))
        ],
      );
}
