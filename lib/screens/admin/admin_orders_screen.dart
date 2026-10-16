import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  final ApiService api;

  const AdminOrdersScreen({super.key, required this.api});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _searchController = TextEditingController();
  AdminOrderPage? _page;
  List<AdminDeliveryPerson> _deliveryPeople = const [];
  String? _status;
  String? _error;
  String? _deliveryError;
  String? _savingId;
  bool _loading = true;
  bool _clearingItemDetails = false;
  int _pageNumber = 1;

  static const _statuses = <(String, String)>[
    ('PLACED', 'New'),
    ('CONFIRMED', 'Confirmed'),
    ('PROCESSING', 'Preparing'),
    ('OUT_FOR_DELIVERY', 'Out for delivery'),
    ('DELIVERED', 'Delivered'),
    ('CANCELLED', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _deliveryError = null;
    });
    try {
      final result = await _adminApi.getOrders(
        page: _pageNumber,
        search: _searchController.text,
        status: _status,
      );
      List<AdminDeliveryPerson> people = _deliveryPeople;
      String? deliveryError;
      try {
        people = await _adminApi.getDeliveryPeople();
      } catch (error) {
        deliveryError =
            'Delivery assignments could not load: ${error.toString().replaceFirst('Exception: ', '')}';
      }
      if (!mounted) return;
      setState(() {
        _page = result;
        _deliveryPeople = people;
        _deliveryError = deliveryError;
        _loading = false;
        _savingId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _savingId = null;
      });
    }
  }

  Future<void> _assignDeliveryPerson(
    AdminOrder order,
    AdminDeliveryPerson person,
  ) async {
    setState(() => _savingId = order.id);
    try {
      await _adminApi.assignDeliveryPerson(order.id, person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${order.orderNumber} assigned to ${person.name}.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<String> _allowedStatuses(AdminOrder order) {
    if (order.deliveryId != null && order.status != 'CANCELLED') {
      return order.status == 'PROCESSING' &&
              ['ASSIGNED', 'DECLINED', 'FAILED'].contains(order.deliveryStatus)
          ? ['CANCELLED']
          : const [];
    }
    return switch (order.status) {
      'PLACED' => ['CONFIRMED', 'CANCELLED'],
      'CONFIRMED' => ['PROCESSING', 'CANCELLED'],
      'PROCESSING' => ['OUT_FOR_DELIVERY', 'CANCELLED'],
      'OUT_FOR_DELIVERY' => ['DELIVERED'],
      _ => const [],
    };
  }

  Future<void> _changeStatus(AdminOrder order, String nextStatus) async {
    if (nextStatus == 'CANCELLED') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: Text(
            'Available stock will be restored for ${order.orderNumber}. '
            'If the customer already paid online, handle the refund separately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _savingId = order.id);
    try {
      await _adminApi.updateOrderStatus(order.id, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${order.orderNumber}: ${_statusLabel(nextStatus)}',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _chooseDeliveryTime(AdminOrder order) async {
    final now = DateTime.now();
    final savedTime = order.scheduledDeliveryAt?.toLocal();
    final current = savedTime != null && savedTime.isAfter(now)
        ? savedTime
        : now.add(const Duration(hours: 1));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selectedTime == null || !mounted) return;
    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future delivery time.')),
      );
      return;
    }
    await _saveDeliveryTime(order, scheduledAt);
  }

  Future<void> _clearDeliveryTime(AdminOrder order) =>
      _saveDeliveryTime(order, null);

  Future<void> _saveDeliveryTime(
    AdminOrder order,
    DateTime? scheduledAt,
  ) async {
    setState(() => _savingId = order.id);
    try {
      await _adminApi.updateOrderDeliveryTime(order.id, scheduledAt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduledAt == null
                ? 'Delivery time cleared for ${order.orderNumber}.'
                : 'Delivery time saved for ${order.orderNumber}.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _clearAllOrderItemDetails() async {
    if (_clearingItemDetails) return;
    var confirmationText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clear all order item details?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently removes product line items from every '
                'order. Orders, totals, payments, delivery records, and '
                'status history will remain.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('clear-order-items-confirmation'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Type CONFIRM DELETE',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  confirmationText = value;
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmationText == 'CONFIRM DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete item details'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        _clearingItemDetails = true;
        _error = null;
      });
      final deletedItems = await _adminApi.clearAllOrderItemDetails(
        confirmation: confirmationText,
      );
      if (!mounted) return;
      setState(() => _clearingItemDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedItems == 0
                ? 'There were no order item details to delete.'
                : 'Deleted item details for $deletedItems '
                    '${deletedItems == 1 ? 'order item' : 'order items'}.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearingItemDetails = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _statusLabel(String status) {
    for (final entry in _statuses) {
      if (entry.$1 == status) return entry.$2;
    }
    return status.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final orders = _page?.orders ?? const <AdminOrder>[];
    final pagination = _page?.pagination;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Orders',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                key: const ValueKey('clear-all-order-item-details'),
                tooltip: 'Delete all order item details',
                onPressed:
                    _clearingItemDetails ? null : _clearAllOrderItemDetails,
                color: Theme.of(context).colorScheme.error,
                icon: _clearingItemDetails
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Review customer details and move each order through its delivery status.',
            style: TextStyle(color: AppConstants.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _pageNumber = 1;
              _load();
            },
            decoration: InputDecoration(
              hintText: 'Search order, customer or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search orders',
                onPressed: () {
                  _pageNumber = 1;
                  _load();
                },
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _StatusFilterChip(
                  label: 'All orders',
                  selected: _status == null,
                  onTap: () => _selectStatus(null),
                ),
                for (final status in _statuses)
                  _StatusFilterChip(
                    label: status.$2,
                    selected: _status == status.$1,
                    onTap: () => _selectStatus(status.$1),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _OrderNotice(message: _error!),
          ],
          if (_deliveryError != null) ...[
            const SizedBox(height: 8),
            _OrderNotice(message: _deliveryError!),
          ],
          const SizedBox(height: 8),
          if (_loading && _page == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            const _EmptyOrders()
          else
            ...orders.map((order) {
              final actions = _allowedStatuses(order);
              final canAssign = order.status == 'PROCESSING'
                  ? order.deliveryId == null ||
                      ['ASSIGNED', 'DECLINED', 'FAILED']
                          .contains(order.deliveryStatus)
                  : order.status == 'OUT_FOR_DELIVERY' &&
                      ['DECLINED', 'FAILED'].contains(order.deliveryStatus);
              return _AdminOrderCard(
                order: order,
                deliveryPeople: _deliveryPeople
                    .where((person) => person.isActive && person.isAvailable)
                    .toList(),
                statusLabel: _statusLabel(order.status),
                statusOptions: actions,
                statusLabelFor: _statusLabel,
                isSaving: _savingId == order.id,
                onStatusSelected: (value) => _changeStatus(order, value),
                onDeliveryPersonSelected: (person) =>
                    _assignDeliveryPerson(order, person),
                canAssign: canAssign,
                canChangeDeliveryTime:
                    order.status != 'DELIVERED' && order.status != 'CANCELLED',
                onSetDeliveryTime: () => _chooseDeliveryTime(order),
                onClearDeliveryTime: () => _clearDeliveryTime(order),
              );
            }),
          if (pagination != null && pagination.total > pagination.pageSize)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _pageNumber <= 1
                      ? null
                      : () {
                          _pageNumber--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  'Page ${pagination.page} of '
                  '${(pagination.total / pagination.pageSize).ceil()}',
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed:
                      _pageNumber * pagination.pageSize >= pagination.total
                          ? null
                          : () {
                              _pageNumber++;
                              _load();
                            },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _selectStatus(String? status) {
    setState(() {
      _status = status;
      _pageNumber = 1;
    });
    _load();
  }
}

class _AdminOrderCard extends StatelessWidget {
  final AdminOrder order;
  final List<AdminDeliveryPerson> deliveryPeople;
  final String statusLabel;
  final List<String> statusOptions;
  final String Function(String) statusLabelFor;
  final bool isSaving;
  final ValueChanged<String> onStatusSelected;
  final ValueChanged<AdminDeliveryPerson> onDeliveryPersonSelected;
  final bool canAssign;
  final bool canChangeDeliveryTime;
  final VoidCallback onSetDeliveryTime;
  final VoidCallback onClearDeliveryTime;

  const _AdminOrderCard({
    required this.order,
    required this.deliveryPeople,
    required this.statusLabel,
    required this.statusOptions,
    required this.statusLabelFor,
    required this.isSaving,
    required this.onStatusSelected,
    required this.onDeliveryPersonSelected,
    required this.canAssign,
    required this.canChangeDeliveryTime,
    required this.onSetDeliveryTime,
    required this.onClearDeliveryTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppConstants.borderLight),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${order.customerName} · ${order.customerPhone}\n'
            '${statusLabel.toUpperCase()} · ${order.paymentMethod} '
            '${order.paymentStatus} · Rs. ${order.total.toStringAsFixed(0)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
        trailing: isSaving
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _DetailLine(
            label: 'Deliver to',
            value: [
              order.customerName,
              order.shippingAddress,
              order.customerPhone,
            ].where((value) => value.trim().isNotEmpty).join('\n'),
          ),
          if (order.deliveryInstructions.isNotEmpty)
            _DetailLine(
              label: 'Delivery notes',
              value: order.deliveryInstructions,
            ),
          const SizedBox(height: 8),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}${item.isWholesale ? ' · wholesale' : ''}'
                      ' × ${item.quantity}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('Rs. ${item.total.toStringAsFixed(0)}'),
                ],
              ),
            ),
          const Divider(height: 16),
          _DetailLine(
            label: 'Subtotal',
            value: 'Rs. ${order.subtotal.toStringAsFixed(0)}',
          ),
          _DetailLine(
            label: 'Delivery',
            value: 'Rs. ${order.deliveryFee.toStringAsFixed(0)}',
          ),
          _DetailLine(
            label: 'Payment',
            value: '${order.paymentMethod} · ${order.paymentStatus}',
          ),
          const SizedBox(height: 8),
          _DetailLine(
            label: 'Estimated delivery',
            value: order.scheduledDeliveryAt == null
                ? 'Not set'
                : DateFormat('EEE, d MMM · h:mm a')
                    .format(order.scheduledDeliveryAt!.toLocal()),
          ),
          if (canChangeDeliveryTime)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : onSetDeliveryTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      order.scheduledDeliveryAt == null
                          ? 'Set delivery time'
                          : 'Change time',
                    ),
                  ),
                  if (order.scheduledDeliveryAt != null)
                    TextButton(
                      onPressed: isSaving ? null : onClearDeliveryTime,
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          if (canAssign || order.deliveryPersonName != null) ...[
            const SizedBox(height: 8),
            _DetailLine(
              label: 'Delivery staff',
              value: order.deliveryPersonName ?? 'Not assigned',
            ),
            if (order.deliveryStatus != null)
              _DetailLine(
                label: 'Delivery status',
                value: order.deliveryStatus!.replaceAll('_', ' '),
              ),
            if (order.deliveryHistory.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Delivery history',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final entry in order.deliveryHistory)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppConstants.primary,
                      ),
                      title: Text(
                        entry['status']?.toString().replaceAll('_', ' ') ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        [
                          entry['note']?.toString(),
                          entry['createdAt']?.toString(),
                        ]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join('\n'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            if (canAssign) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<AdminDeliveryPerson>(
                  enabled: !isSaving && deliveryPeople.isNotEmpty,
                  onSelected: onDeliveryPersonSelected,
                  itemBuilder: (context) => deliveryPeople
                      .map(
                        (person) => PopupMenuItem(
                          value: person,
                          child: Text(
                            '${person.name} · ${person.activeDeliveries} active',
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 18),
                        const SizedBox(width: 7),
                        Text(
                          order.deliveryPersonName == null
                              ? (deliveryPeople.isEmpty
                                  ? 'No staff on duty'
                                  : 'Assign delivery')
                              : 'Assign / reassign',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (statusOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                enabled: !isSaving,
                onSelected: onStatusSelected,
                itemBuilder: (context) => statusOptions
                    .map(
                      (status) => PopupMenuItem(
                        value: status,
                        child: Text(statusLabelFor(status)),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, size: 18),
                      SizedBox(width: 7),
                      Text('Update order status'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _OrderNotice extends StatelessWidget {
  final String message;

  const _OrderNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF8A4B08))),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 42, color: AppConstants.primary),
          const SizedBox(height: 12),
          const Text('No orders found',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'New customer orders will appear here.',
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
}
