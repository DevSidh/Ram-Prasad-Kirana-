import '../../widgets/billing_localized_widgets.dart';
import '../../widgets/product_identity.dart';
import '../../core/billing_strings.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admin_models.dart';
import '../../core/order_time.dart';
import '../../services/admin_order_notification_service.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../services/online_order_archive_service.dart';
import '../../services/store_audio_service.dart';
import '../../theme/app_colors.dart';

class AdminOrdersScreen extends StatefulWidget {
  final ApiService api;
  final bool isActive;
  final AdminOrderNotificationService? notificationService;
  final ValueChanged<int>? onUnreadOrderCountChanged;

  const AdminOrdersScreen({
    super.key,
    required this.api,
    this.isActive = false,
    this.notificationService,
    this.onUnreadOrderCountChanged,
  });

  @override
  AdminOrdersScreenState createState() => AdminOrdersScreenState();
}

class AdminOrdersScreenState extends State<AdminOrdersScreen>
    with WidgetsBindingObserver {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  late final AdminOrderNotificationService _notificationService =
      widget.notificationService ?? const AdminOrderNotificationService();
  final OnlineOrderArchiveService _orderArchive =
      const OnlineOrderArchiveService();
  final _searchController = TextEditingController();
  AdminOrderPage? _page;
  List<AdminDeliveryPerson> _deliveryPeople = const [];
  String? _status;
  DateTime? _selectedDay;
  String? _error;
  String? _deliveryError;
  String? _savingId;
  bool _loading = true;
  int _loadRequest = 0;
  final Map<String, String> _optimisticStatuses = {};
  Timer? _orderPollTimer;
  bool _hasPollBaseline = false;
  bool _pollInFlight = false;
  bool _archiveInFlight = false;
  bool _archiveRefreshQueued = false;
  DateTime? _lastArchiveSyncAt;
  String? _archiveError;
  bool _isAppForeground = true;
  final Set<String> _seenOrderIds = {};
  final Set<String> _unreadOrderIds = {};
  int _pageNumber = 1;
  static const _readOrderIdsPreferenceKey = 'admin_read_order_alert_ids_v1';

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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepareOnlineOrderArchive());
    _load();
    if (widget.isActive) _startOrderPolling();
  }

  bool get _supportsComputerArchive =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _prepareOnlineOrderArchive() async {
    if (!_supportsComputerArchive) return;
    try {
      await _orderArchive.ensureFolders();
      await _syncOnlineOrderArchive(force: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _archiveError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _syncOnlineOrderArchive({bool force = false}) async {
    if (!_supportsComputerArchive) return;
    final lastSync = _lastArchiveSyncAt;
    if (!force &&
        lastSync != null &&
        DateTime.now().difference(lastSync) < const Duration(minutes: 2)) {
      return;
    }
    if (_archiveInFlight) {
      if (force) _archiveRefreshQueued = true;
      return;
    }

    _archiveInFlight = true;
    var succeeded = false;
    try {
      const pageSize = 100;
      final firstPage = await _adminApi.getOrders(page: 1, pageSize: pageSize);
      final allOrders = <AdminOrder>[...firstPage.orders];
      final effectivePageSize = firstPage.pagination.pageSize > 0
          ? firstPage.pagination.pageSize
          : pageSize;
      final pageCount = (firstPage.pagination.total / effectivePageSize).ceil();
      for (var page = 2; page <= pageCount; page++) {
        final result =
            await _adminApi.getOrders(page: page, pageSize: pageSize);
        allOrders.addAll(result.orders);
      }
      await _orderArchive.archiveOrders(allOrders);
      succeeded = true;
      if (mounted && _archiveError != null) {
        setState(() => _archiveError = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _archiveError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _archiveInFlight = false;
      if (succeeded) _lastArchiveSyncAt = DateTime.now();
      if (_archiveRefreshQueued) {
        _archiveRefreshQueued = false;
        unawaited(_syncOnlineOrderArchive(force: true));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    if (_isAppForeground) {
      if (widget.isActive) _startOrderPolling(resetBaseline: false);
    } else {
      _pauseOrderPolling();
    }
  }

  @override
  void didUpdateWidget(covariant AdminOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _startOrderPolling();
    } else {
      _stopOrderPolling();
    }
  }

  @override
  void dispose() {
    _stopOrderPolling();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _startOrderPolling({bool resetBaseline = true}) {
    if (!_isAppForeground || !widget.isActive) return;
    _orderPollTimer?.cancel();
    if (resetBaseline) _hasPollBaseline = false;
    unawaited(_notificationService.requestPermission());
    unawaited(_pollOrders());
    _orderPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_pollOrders()),
    );
  }

  void _stopOrderPolling() {
    _orderPollTimer?.cancel();
    _orderPollTimer = null;
    _hasPollBaseline = false;
  }

  void _pauseOrderPolling() {
    _orderPollTimer?.cancel();
    _orderPollTimer = null;
  }

  Future<void> _pollOrders() async {
    if (!widget.isActive || !_isAppForeground || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final incoming = await _adminApi.getRecentOrderAlerts();
      if (!mounted || !widget.isActive || !_isAppForeground) return;
      if (!_hasPollBaseline) {
        final preferences = await SharedPreferences.getInstance();
        final storedReadIds =
            preferences.getStringList(_readOrderIdsPreferenceKey);
        final knownReadIds = storedReadIds?.toSet();
        final newOrders = storedReadIds == null
            ? const <({String id, String orderNumber})>[]
            : incoming
                .where((order) => !knownReadIds!.contains(order.id))
                .toList(growable: false);
        _seenOrderIds.addAll(incoming.map((order) => order.id));
        if (storedReadIds == null) {
          await preferences.setStringList(
            _readOrderIdsPreferenceKey,
            _seenOrderIds.toList(growable: false),
          );
        }
        _hasPollBaseline = true;
        if (newOrders.isNotEmpty) _announceNewOrders(newOrders);
        widget.onUnreadOrderCountChanged?.call(_unreadOrderIds.length);
        return;
      }
      final newOrders =
          incoming.where((order) => _seenOrderIds.add(order.id)).toList();
      if (newOrders.isNotEmpty) _announceNewOrders(newOrders);
    } catch (_) {
      // Keep the existing order list usable when a background check fails.
    } finally {
      _pollInFlight = false;
    }
  }

  void _announceNewOrders(List<({String id, String orderNumber})> newOrders) {
    _unreadOrderIds.addAll(newOrders.map((order) => order.id));
    widget.onUnreadOrderCountChanged?.call(_unreadOrderIds.length);
    unawaited(StoreAudioService.playNotification());
    for (final order in newOrders) {
      unawaited(_notificationService.showNewOrder(order.orderNumber));
    }
    final order = newOrders.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BillingText(
          newOrders.length == 1
              ? 'New order received: ${order.orderNumber}'
              : '${newOrders.length} new orders received. Latest: ${order.orderNumber}',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    unawaited(_load(forceArchive: true));
  }

  /// Clears the delivery badge when the administrator opens the order list.
  void markOrdersRead() {
    if (_unreadOrderIds.isEmpty) return;
    _unreadOrderIds.clear();
    widget.onUnreadOrderCountChanged?.call(0);
    unawaited(_saveReadOrders());
  }

  Future<void> _saveReadOrders() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final previous =
          preferences.getStringList(_readOrderIdsPreferenceKey) ?? const [];
      final read = <String>{...previous, ..._seenOrderIds};
      await preferences.setStringList(
        _readOrderIdsPreferenceKey,
        read.take(500).toList(growable: false),
      );
    } catch (error) {
      debugPrint('Could not save read order alerts: $error');
    }
  }

  Future<void> _load({bool forceArchive = false}) async {
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
      _deliveryError = null;
    });
    try {
      List<AdminDeliveryPerson> people = _deliveryPeople;
      String? deliveryError;
      late AdminOrderPage result;
      await Future.wait<void>([
        _adminApi
            .getOrders(
              page: _pageNumber,
              search: _searchController.text,
              status: _status,
              day: _selectedDay,
            )
            .then<void>((value) => result = value),
        _adminApi.getDeliveryPeople().then<void>((value) {
          people = value;
        }).catchError((Object error) {
          deliveryError =
              'Delivery assignments could not load: ${error.toString().replaceFirst('Exception: ', '')}';
        }),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _page = result;
        _deliveryPeople = people;
        _deliveryError = deliveryError;
        _loading = false;
        _savingId = null;
        _optimisticStatuses.clear();
      });
      unawaited(_syncOnlineOrderArchive(force: forceArchive));
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
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
            content: BillingText(
                '${order.orderNumber} assigned to ${person.name}.')),
      );
      await _load(forceArchive: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _effectiveStatus(AdminOrder order) =>
      _optimisticStatuses[order.id] ?? order.status;

  List<String> _allowedStatuses(AdminOrder order) {
    final status = _effectiveStatus(order);
    if (order.deliveryId != null && status != 'CANCELLED') {
      return status == 'PROCESSING' &&
              ['ASSIGNED', 'DECLINED', 'FAILED'].contains(order.deliveryStatus)
          ? ['CANCELLED']
          : const [];
    }
    return switch (status) {
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
          title: const BillingText('Cancel this order?'),
          content: BillingText(
            'Available stock will be restored for ${order.orderNumber}. '
            'If the customer already paid online, handle the refund separately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const BillingText('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const BillingText('Cancel order'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() {
      _savingId = order.id;
      _optimisticStatuses[order.id] = nextStatus;
    });
    try {
      await _adminApi.updateOrderStatus(order.id, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BillingText(
            '${order.orderNumber}: ${_statusLabel(nextStatus)}',
          ),
        ),
      );
      unawaited(_load(forceArchive: true));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _optimisticStatuses.remove(order.id);
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
        const SnackBar(content: BillingText('Choose a future delivery time.')),
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
          content: BillingText(
            scheduledAt == null
                ? 'Delivery time cleared for ${order.orderNumber}.'
                : 'Delivery time saved for ${order.orderNumber}.',
          ),
        ),
      );
      await _load(forceArchive: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
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

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (!mounted || day == null) return;
    setState(() => _selectedDay = day);
    _pageNumber = 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _page?.orders ?? const <AdminOrder>[];
    final pagination = _page?.pagination;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 30, 28),
        children: [
          BillingText(
            'Review customer details and update delivery status. Cancelling preserves order, payment, and fulfillment history.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _pageNumber = 1;
              _load();
            },
            decoration: BillingInputDecoration(
              hintText: 'Search order, customer or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: BillingIconButton(
                tooltip: 'Search orders',
                onPressed: () {
                  _pageNumber = 1;
                  _load();
                },
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.input),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _selectDay,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: BillingText(
                  _selectedDay == null
                      ? 'Filter by day'
                      : DateFormat(
                              'EEE, d MMM yyyy', BillingStrings.languageCode)
                          .format(_selectedDay!),
                ),
              ),
              if (_selectedDay != null)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _selectedDay = null);
                          _pageNumber = 1;
                          _load();
                        },
                  child: const BillingText('Clear day'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _OrderNotice(message: _error!),
          ],
          if (_deliveryError != null) ...[
            const SizedBox(height: 8),
            _OrderNotice(message: _deliveryError!),
          ],
          if (_archiveError != null) ...[
            const SizedBox(height: 8),
            _OrderNotice(
              message:
                  'Local online-order archive could not sync: $_archiveError',
            ),
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
                statusLabel: _statusLabel(_effectiveStatus(order)),
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
                BillingIconButton(
                  tooltip: 'Previous page',
                  onPressed: _pageNumber <= 1
                      ? null
                      : () {
                          _pageNumber--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                BillingText(
                  'Page ${pagination.page} of '
                  '${(pagination.total / pagination.pageSize).ceil()}',
                ),
                BillingIconButton(
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.row),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: BillingText(
          order.orderNumber,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: BillingText(
            '${order.customerName} · ${order.customerPhone}\n'
            'ORDERED ${formatOrderPlacedAt(order.createdAt)}\n'
            '${statusLabel.toUpperCase()} · ${order.paymentMethod} '
            '${order.paymentStatus} · Rs. ${order.total.toStringAsFixed(0)}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
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
                  CatalogProductThumbnail(
                      sku: item.sku, imageUrl: item.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BillingText(
                      '${item.name}${item.isWholesale ? ' · wholesale' : ''}'
                      ' × ${item.quantity}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BillingText('Rs. ${item.total.toStringAsFixed(0)}'),
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
                : DateFormat('EEE, d MMM · h:mm a', BillingStrings.languageCode)
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
                    label: BillingText(
                      order.scheduledDeliveryAt == null
                          ? 'Set delivery time'
                          : 'Change time',
                    ),
                  ),
                  if (order.scheduledDeliveryAt != null)
                    TextButton(
                      onPressed: isSaving ? null : onClearDeliveryTime,
                      child: const BillingText('Clear'),
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
                title: BillingText(
                  'Delivery history',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                children: [
                  for (final entry in order.deliveryHistory)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.primary,
                      ),
                      title: BillingText(
                        entry['status']?.toString().replaceAll('_', ' ') ?? '',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      subtitle: BillingText(
                        [
                          entry['note']?.toString(),
                          entry['createdAt']?.toString(),
                        ]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join('\n'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            if (canAssign) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: BillingPopupMenuButton<AdminDeliveryPerson>(
                  enabled: !isSaving && deliveryPeople.isNotEmpty,
                  onSelected: onDeliveryPersonSelected,
                  itemBuilder: (context) => deliveryPeople
                      .map(
                        (person) => PopupMenuItem(
                          value: person,
                          child: BillingText(
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
                      color: AppColors.pageEnd,
                      borderRadius: BorderRadius.circular(AppRadii.row),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 18),
                        const SizedBox(width: 7),
                        BillingText(
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
              child: BillingPopupMenuButton<String>(
                enabled: !isSaving,
                onSelected: onStatusSelected,
                itemBuilder: (context) => statusOptions
                    .map(
                      (status) => PopupMenuItem(
                        value: status,
                        child: BillingText(statusLabelFor(status)),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.pageEnd,
                    borderRadius: BorderRadius.circular(AppRadii.row),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, size: 18),
                      SizedBox(width: 7),
                      BillingText('Update order status'),
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
            child: BillingText(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: BillingText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
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
        label: BillingText(label),
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
        color: AppColors.warningPill,
        borderRadius: BorderRadius.circular(AppRadii.row),
      ),
      child: BillingText(
        message,
        style: TextStyle(color: AppColors.warningText),
      ),
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
          Icon(Icons.receipt_long_outlined, size: 42, color: AppColors.primary),
          const SizedBox(height: 12),
          const BillingText('No orders found',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          BillingText(
            'New customer orders will appear here.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
