import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminDeliveryPeopleScreen extends StatefulWidget {
  final ApiService api;

  const AdminDeliveryPeopleScreen({super.key, required this.api});

  @override
  State<AdminDeliveryPeopleScreen> createState() =>
      _AdminDeliveryPeopleScreenState();
}

class _AdminDeliveryPeopleScreenState extends State<AdminDeliveryPeopleScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  List<AdminDeliveryPerson> _people = const [];
  List<AdminPendingDeliveryCash> _pendingCash = const [];
  AdminOrderPage? _deliveryOrderPage;
  String _deliveryFilter = 'all';
  String? _deliveryError;
  String? _assigningOrderId;
  bool _loadingDeliveries = true;
  int _deliveryPageNumber = 1;
  String? _error;
  String? _savingId;
  String? _cashSavingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ordersLoad = _loadDeliveryOrders();
    try {
      final people = await _adminApi.getDeliveryPeople();
      List<AdminPendingDeliveryCash> pendingCash = const [];
      String? cashError;
      try {
        pendingCash = await _adminApi.getPendingDeliveryCash();
      } catch (error) {
        cashError = error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted) return;
      setState(() {
        _people = people;
        _pendingCash = pendingCash;
        _loading = false;
        _savingId = null;
        _cashSavingId = null;
        _error = cashError;
      });
      await ordersLoad;
    } catch (error) {
      await ordersLoad;
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadDeliveryOrders() async {
    if (mounted) {
      setState(() {
        _loadingDeliveries = true;
        _deliveryError = null;
      });
    }
    try {
      final page = await _adminApi.getOrders(
        page: _deliveryPageNumber,
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _deliveryOrderPage = page;
        _loadingDeliveries = false;
        _assigningOrderId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deliveryError = error.toString().replaceFirst('Exception: ', '');
        _loadingDeliveries = false;
        _assigningOrderId = null;
      });
    }
  }

  Future<void> _assignOrder(AdminOrder order, AdminDeliveryPerson person) async {
    setState(() => _assigningOrderId = order.id);
    try {
      await _adminApi.assignDeliveryPerson(order.id, person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.orderNumber} assigned to ${person.name}.'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assigningOrderId = null;
        _deliveryError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<AdminOrder> get _filteredDeliveryOrders {
    final orders = _deliveryOrderPage?.orders ?? const <AdminOrder>[];
    return orders.where((order) {
      final deliveryStatus = order.deliveryStatus;
      final active = const {
        'ASSIGNED',
        'ACCEPTED',
        'PICKED_UP',
        'OUT_FOR_DELIVERY',
      }.contains(deliveryStatus);
      final terminal = const {
        'DELIVERED',
        'DECLINED',
        'FAILED',
        'CANCELLED',
      }.contains(deliveryStatus) ||
          const {'DELIVERED', 'CANCELLED'}.contains(order.status);
      final needsAssignment = order.status == 'PROCESSING' &&
              (deliveryStatus == null ||
                  const {'DECLINED', 'FAILED'}.contains(deliveryStatus)) ||
          order.status == 'OUT_FOR_DELIVERY' &&
              const {'DECLINED', 'FAILED'}.contains(deliveryStatus);
      return switch (_deliveryFilter) {
        'needs_assignment' => needsAssignment,
        'active' => active,
        'completed' => terminal,
        _ => true,
      };
    }).toList();
  }

  Future<void> _createPerson() async {
    final fields = await showDialog<_NewDeliveryPerson>(
      context: context,
      builder: (context) => const _NewDeliveryPersonDialog(),
    );
    if (fields == null || !mounted) return;
    setState(() => _savingId = 'new');
    try {
      await _adminApi.createDeliveryPerson(
        name: fields.name,
        email: fields.email,
        phone: fields.phone,
        password: fields.password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery account created.')),
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

  Future<void> _toggleActive(AdminDeliveryPerson person) async {
    final isActive = !person.isActive;
    if (!isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove delivery staff?'),
          content: Text(
            '${person.name} will be removed from the active staff roster. '
            'Their account and delivery history will be kept. '
            'Finish or reassign active deliveries first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove staff'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _savingId = person.id);
    try {
      await _adminApi.setDeliveryPersonActive(person.id, isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? '${person.name} restored to the active roster.'
                : '${person.name} removed from the active roster.',
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

  Future<void> _confirmCashHandover(AdminPendingDeliveryCash delivery) async {
    setState(() => _cashSavingId = delivery.id);
    try {
      await _adminApi.confirmDeliveryCashHandover(delivery.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rs. ${delivery.cashCollected.toStringAsFixed(2)} received for ${delivery.orderNumber}.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cashSavingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery team',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create staff accounts and check who is on duty.',
                      style: TextStyle(color: AppConstants.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _savingId == 'new' ? null : _createPerson,
                icon: _savingId == 'new'
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add staff'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SalaryNotice(),
          const SizedBox(height: 12),
          _CashHandoverSection(
            deliveries: _pendingCash,
            isLoading: _loading,
            savingId: _cashSavingId,
            onConfirm: _confirmCashHandover,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _DeliveryAdminNotice(message: _error!),
          ],
          const SizedBox(height: 22),
          _buildDeliveryBoard(),
          const SizedBox(height: 12),
          if (_loading && _people.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_people.isEmpty)
            const _EmptyRiders()
          else
            for (final person in _people)
              _DeliveryPersonCard(
                person: person,
                isSaving: _savingId == person.id,
                onToggleActive: () => _toggleActive(person),
              ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBoard() {
    final page = _deliveryOrderPage;
    final orders = _filteredDeliveryOrders;
    final availablePeople =
        _people.where((person) => person.isActive && person.isAvailable).toList();
    final pagination = page?.pagination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery board',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Review orders, customer details and rider progress. Assign ready orders to an on-duty rider.',
          style: TextStyle(color: AppConstants.textMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 4,
          children: [
            _DeliveryFilterChip(
              label: 'All orders',
              selected: _deliveryFilter == 'all',
              onTap: () => setState(() => _deliveryFilter = 'all'),
            ),
            _DeliveryFilterChip(
              label: 'Needs rider',
              selected: _deliveryFilter == 'needs_assignment',
              onTap: () => setState(() => _deliveryFilter = 'needs_assignment'),
            ),
            _DeliveryFilterChip(
              label: 'Active',
              selected: _deliveryFilter == 'active',
              onTap: () => setState(() => _deliveryFilter = 'active'),
            ),
            _DeliveryFilterChip(
              label: 'Closed',
              selected: _deliveryFilter == 'completed',
              onTap: () => setState(() => _deliveryFilter = 'completed'),
            ),
          ],
        ),
        if (_deliveryError != null) ...[
          const SizedBox(height: 9),
          _DeliveryAdminNotice(message: _deliveryError!),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadingDeliveries ? null : _loadDeliveryOrders,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry delivery board'),
            ),
          ),
        ],
        if (_loadingDeliveries && page == null)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No orders match this delivery view.',
              style: TextStyle(color: AppConstants.textMuted),
            ),
          )
        else
          for (final order in orders)
            _DeliveryOrderAdminCard(
              order: order,
              availablePeople: availablePeople,
              isAssigning: _assigningOrderId == order.id,
              canAssign: order.status == 'PROCESSING' &&
                      (order.deliveryId == null ||
                          const {'ASSIGNED', 'DECLINED', 'FAILED'}
                              .contains(order.deliveryStatus)) ||
                  order.status == 'OUT_FOR_DELIVERY' &&
                      const {'DECLINED', 'FAILED'}
                          .contains(order.deliveryStatus),
              onAssign: (person) => _assignOrder(order, person),
            ),
        if (pagination != null && pagination.total > pagination.pageSize)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous delivery page',
                onPressed: _deliveryPageNumber <= 1 || _loadingDeliveries
                    ? null
                    : () {
                        setState(() => _deliveryPageNumber--);
                        _loadDeliveryOrders();
                      },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Page ${pagination.page} of '
                '${(pagination.total / pagination.pageSize).ceil()}',
              ),
              IconButton(
                tooltip: 'Next delivery page',
                onPressed:
                    _deliveryPageNumber * pagination.pageSize >=
                                pagination.total ||
                            _loadingDeliveries
                        ? null
                        : () {
                            setState(() => _deliveryPageNumber++);
                            _loadDeliveryOrders();
                          },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        const Divider(height: 28),
        const Text(
          'Delivery team',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DeliveryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppConstants.primaryLight,
      labelStyle: TextStyle(
        color: selected ? AppConstants.primaryDark : AppConstants.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DeliveryOrderAdminCard extends StatelessWidget {
  final AdminOrder order;
  final List<AdminDeliveryPerson> availablePeople;
  final bool isAssigning;
  final bool canAssign;
  final ValueChanged<AdminDeliveryPerson> onAssign;

  const _DeliveryOrderAdminCard({
    required this.order,
    required this.availablePeople,
    required this.isAssigning,
    required this.canAssign,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryStatus =
        order.deliveryStatus?.replaceAll('_', ' ') ?? 'Not assigned';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppConstants.borderLight),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          '${order.orderNumber} · ${order.customerName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$deliveryStatus · ${order.status.replaceAll('_', ' ')} · '
            'Rs. ${order.total.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppConstants.textMuted,
              fontSize: 11,
            ),
          ),
        ),
        trailing: isAssigning
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _AdminDeliveryDetail(
            label: 'Customer',
            value: [
              order.customerName,
              order.customerPhone,
              order.customerEmail,
            ].where((value) => value.trim().isNotEmpty).join('\n'),
          ),
          _AdminDeliveryDetail(
            label: 'Address',
            value: order.shippingAddress.isEmpty
                ? 'No delivery address provided'
                : order.shippingAddress,
          ),
          if (order.deliveryInstructions.trim().isNotEmpty)
            _AdminDeliveryDetail(
              label: 'Instructions',
              value: order.deliveryInstructions,
            ),
          const SizedBox(height: 6),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} × ${item.quantity}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    'Rs. ${item.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(height: 18),
          _AdminDeliveryDetail(
            label: 'Payment',
            value: '${order.paymentMethod} · ${order.paymentStatus} · '
                'Rs. ${order.total.toStringAsFixed(0)}',
          ),
          _AdminDeliveryDetail(
            label: 'Assigned rider',
            value: order.deliveryPersonName ?? 'Not assigned',
          ),
          if (order.deliveryHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final entry in order.deliveryHistory.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  [
                    entry['status']?.toString().replaceAll('_', ' '),
                    entry['note']?.toString(),
                  ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
          if (canAssign) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<AdminDeliveryPerson>(
                enabled: !isAssigning && availablePeople.isNotEmpty,
                onSelected: onAssign,
                itemBuilder: (context) => availablePeople
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        availablePeople.isEmpty
                            ? 'No rider on duty'
                            : order.deliveryPersonName == null
                                ? 'Assign rider'
                                : 'Reassign rider',
                      ),
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

class _AdminDeliveryDetail extends StatelessWidget {
  final String label;
  final String value;

  const _AdminDeliveryDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _CashHandoverSection extends StatelessWidget {
  final List<AdminPendingDeliveryCash> deliveries;
  final bool isLoading;
  final String? savingId;
  final ValueChanged<AdminPendingDeliveryCash> onConfirm;

  const _CashHandoverSection({
    required this.deliveries,
    required this.isLoading,
    required this.savingId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final total = deliveries.fold<double>(
      0,
      (sum, delivery) => sum + delivery.cashCollected,
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppConstants.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Customer COD to receive',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Confirm only after the delivery staff hands the collected cash to the store.',
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (isLoading && deliveries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (deliveries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No customer cash is waiting for store handover.',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                ),
              )
            else
              for (final delivery in deliveries) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${delivery.deliveryPersonName} · Rs. ${delivery.cashCollected.toStringAsFixed(2)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: savingId == delivery.id
                          ? null
                          : () => onConfirm(delivery),
                      child: savingId == delivery.id
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm received'),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _DeliveryPersonCard extends StatelessWidget {
  final AdminDeliveryPerson person;
  final bool isSaving;
  final VoidCallback onToggleActive;

  const _DeliveryPersonCard({
    required this.person,
    required this.isSaving,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppConstants.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: person.isActive
                  ? AppConstants.primaryLight
                  : const Color(0xFFE9ECE9),
              child: Icon(
                Icons.delivery_dining_rounded,
                color: person.isActive
                    ? AppConstants.primaryDark
                    : AppConstants.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    person.phone.isEmpty
                        ? person.email
                        : '${person.phone} · ${person.email}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${person.isAvailable ? 'On duty' : 'Off duty'} · '
                    '${person.activeDeliveries} active deliveries',
                    style: TextStyle(
                      color: person.isActive
                          ? AppConstants.primaryDark
                          : AppConstants.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            if (isSaving)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: person.isActive
                    ? 'Remove delivery staff from roster'
                    : 'Restore delivery staff to roster',
                onPressed: onToggleActive,
                icon: Icon(
                  person.isActive
                      ? Icons.person_remove_outlined
                      : Icons.person_add_alt_1_rounded,
                  color:
                      person.isActive ? Colors.redAccent : AppConstants.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewDeliveryPerson {
  final String name;
  final String email;
  final String phone;
  final String password;

  const _NewDeliveryPerson({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });
}

class _NewDeliveryPersonDialog extends StatefulWidget {
  const _NewDeliveryPersonDialog();

  @override
  State<_NewDeliveryPersonDialog> createState() =>
      _NewDeliveryPersonDialogState();
}

class _NewDeliveryPersonDialogState extends State<_NewDeliveryPersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add delivery staff'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _required,
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (_required(value) != null) return 'Enter an email address.';
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value!.trim())
                      ? null
                      : 'Enter a valid email address.';
                },
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Temporary sign-in password',
                  helperText: 'At least 10 characters. Share it securely.',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => value != null && value.length >= 10
                    ? null
                    : 'Use at least 10 characters.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _NewDeliveryPerson(
                name: _name.text.trim(),
                email: _email.text.trim(),
                phone: _phone.text.trim(),
                password: _password.text,
              ),
            );
          },
          child: const Text('Create account'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class _SalaryNotice extends StatelessWidget {
  const _SalaryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppConstants.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppConstants.primaryDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Delivery staff are monthly salaried. No per-order wages or incentive amounts are configured here.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRiders extends StatelessWidget {
  const _EmptyRiders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 42, color: AppConstants.primary),
          const SizedBox(height: 10),
          const Text(
            'No delivery staff yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a staff account to start assigning prepared orders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DeliveryAdminNotice extends StatelessWidget {
  final String message;

  const _DeliveryAdminNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF8A3312)),
      ),
    );
  }
}
