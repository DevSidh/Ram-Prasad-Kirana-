import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/delivery_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/delivery_api_service.dart';
import '../auth/login_screen.dart';

class DeliveryPanelScreen extends StatefulWidget {
  final ApiService api;

  const DeliveryPanelScreen({super.key, required this.api});

  @override
  State<DeliveryPanelScreen> createState() => _DeliveryPanelScreenState();
}

class _DeliveryPanelScreenState extends State<DeliveryPanelScreen> {
  late final DeliveryApiService _deliveryApi = DeliveryApiService(widget.api);
  Timer? _refreshTimer;
  DeliveryProfile? _profile;
  DeliveryAssignmentPage? _page;
  String? _error;
  String? _savingId;
  String? _filter;
  bool _loading = true;
  int _selectedIndex = 0;
  bool _availabilitySaving = false;

  static const _filters = <(String?, String)>[
    (null, 'All'),
    ('ASSIGNED', 'New'),
    ('ACCEPTED', 'Accepted'),
    ('PICKED_UP', 'Picked up'),
    ('OUT_FOR_DELIVERY', 'On the way'),
    ('DELIVERED', 'Delivered'),
    ('FAILED', 'Failed'),
    ('DECLINED', 'Declined'),
    ('CANCELLED', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh({bool silent = false}) async {
    if (_loading && _page != null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _deliveryApi.getProfile(),
        _deliveryApi.getAssignments(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as DeliveryProfile;
        _page = results[1] as DeliveryAssignmentPage;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _setAvailability(bool value) async {
    if (_availabilitySaving) return;
    setState(() => _availabilitySaving = true);
    try {
      await _deliveryApi.setAvailability(value);
      if (!mounted) return;
      setState(() {
        if (_profile != null) {
          _profile = DeliveryProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            isAvailable: value,
          );
        }
        _availabilitySaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _availabilitySaving = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _update(
    DeliveryAssignment assignment,
    String status, {
    String? reason,
    String? recipientName,
    double? cashCollected,
  }) async {
    setState(() => _savingId = assignment.id);
    try {
      await _deliveryApi.updateAssignment(
        assignment.id,
        status,
        reason: reason,
        recipientName: recipientName,
        cashCollected: cashCollected,
      );
      if (!mounted) return;
      _showMessage('${assignment.order.orderNumber}: ${_statusName(status)}');
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _decline(DeliveryAssignment assignment) async {
    final reason = await _askForReason(
      title: 'Decline this delivery?',
      hint: 'Tell the store why you cannot take this order',
    );
    if (reason == null || !mounted) return;
    await _update(assignment, 'DECLINED', reason: reason);
  }

  Future<void> _reportFailure(DeliveryAssignment assignment) async {
    final reason = await _askForReason(
      title: 'Report a failed delivery',
      hint: 'For example: customer unavailable or address not found',
    );
    if (reason == null || !mounted) return;
    await _update(assignment, 'FAILED', reason: reason);
  }

  Future<String?> _askForReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason',
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Save reason'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _completeDelivery(DeliveryAssignment assignment) async {
    final nameController = TextEditingController();
    final cashController = TextEditingController(
      text: assignment.order.cashDue.toStringAsFixed(2),
    );
    final requiresCash = assignment.order.cashDue > 0.009;
    final result = await showDialog<(String, double)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${assignment.order.orderNumber}'),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Received by',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (requiresCash)
              TextField(
                controller: cashController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cash collected (Rs.)',
                  helperText:
                      'Collect the exact amount due: Rs. ${assignment.order.cashDue.toStringAsFixed(2)}',
                  border: const OutlineInputBorder(),
                ),
              )
            else
              const Text('Paid online · Rs. 0 COD due'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final cash = requiresCash
                  ? double.tryParse(cashController.text.trim())
                  : 0;
              if (name.isNotEmpty &&
                  cash != null &&
                  (cash - assignment.order.cashDue).abs() <= 0.01) {
                Navigator.pop(context, (name, cash));
              }
            },
            child: const Text('Confirm delivered'),
          ),
        ],
      ),
    );
    nameController.dispose();
    cashController.dispose();
    if (result == null || !mounted) return;
    await _update(
      assignment,
      'DELIVERED',
      recipientName: result.$1,
      cashCollected: result.$2,
    );
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.trim().isEmpty) {
      _showMessage('No customer phone number is available.');
      return;
    }
    await _openUri(Uri(scheme: 'tel', path: phone.trim()));
  }

  Future<void> _navigate(DeliveryOrder order) async {
    final destination = order.latitude != null && order.longitude != null
        ? '${order.latitude},${order.longitude}'
        : order.address;
    if (destination.trim().isEmpty) {
      _showMessage('This order has no saved delivery address.');
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    await _openUri(uri);
  }

  Future<void> _openUri(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Could not open this app on your device.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not open this app: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusName(String status) => switch (status) {
        'ASSIGNED' => 'new assignment',
        'ACCEPTED' => 'accepted',
        'PICKED_UP' => 'picked up',
        'OUT_FOR_DELIVERY' => 'on the way',
        'DELIVERED' => 'delivered',
        'DECLINED' => 'declined',
        'FAILED' => 'delivery needs follow-up',
        'CANCELLED' => 'cancelled by store',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    const titles = ['Today', 'My deliveries', 'Profile'];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_selectedIndex]),
            Text(
              'DELIVERY TEAM',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                color: AppConstants.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh deliveries',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildTab(),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content:
            const Text('You will need to sign in again to see deliveries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildTab() {
    if (_loading && _page == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _page == null) {
      return _LoadFailure(message: _error!, onRetry: refresh);
    }
    return switch (_selectedIndex) {
      0 => _buildToday(),
      1 => _buildDeliveries(),
      _ => _buildProfile(),
    };
  }

  Widget _buildToday() {
    final summary = _page?.summary;
    final available = _profile?.isAvailable ?? false;
    final nextAssignment = _page?.assignments
        .where((item) => [
              'ASSIGNED',
              'ACCEPTED',
              'PICKED_UP',
              'OUT_FOR_DELIVERY'
            ].contains(item.status))
        .firstOrNull;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _AvailabilityCard(
            name: _profile?.name ?? 'Delivery staff',
            isAvailable: available,
            isSaving: _availabilitySaving,
            onChanged: _setAvailability,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '${summary?.assigned ?? 0}',
                  label: 'New & accepted',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MetricCard(
                  value: '${summary?.inProgress ?? 0}',
                  label: 'In progress',
                  icon: Icons.route_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MetricCard(
                  value: '${summary?.deliveredToday ?? 0}',
                  label: 'Delivered today',
                  icon: Icons.task_alt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CashDueCard(amount: summary?.cashToCollect ?? 0),
          if ((summary?.cashToHandOver ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _CashHandoverDueCard(amount: summary!.cashToHandOver),
          ],
          const SizedBox(height: 20),
          const Text(
            'Next delivery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (nextAssignment == null)
            const _EmptyDeliveries(message: 'No active deliveries right now.')
          else
            _AssignmentCard(
              assignment: nextAssignment,
              isSaving: _savingId == nextAssignment.id,
              onAction: _handleAction,
              onCall: _callCustomer,
              onNavigate: _navigate,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorNotice(message: _error!),
          ],
          const SizedBox(height: 6),
          Text(
            'Assignments refresh automatically while this panel is open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConstants.textMuted.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveries() {
    final assignments = _page?.assignments ?? const <DeliveryAssignment>[];
    final filtered = _filter == null
        ? assignments
        : assignments.where((item) => item.status == _filter).toList();
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            'Your assigned route',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Only deliveries assigned to your account are shown.',
            style: TextStyle(color: AppConstants.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(filter.$2),
                      selected: _filter == filter.$1,
                      onSelected: (_) => setState(() => _filter = filter.$1),
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorNotice(message: _error!),
          ],
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const _EmptyDeliveries(
              message:
                  'Nothing in this list. Pull down to refresh assignments.',
            )
          else
            for (final assignment in filtered)
              _AssignmentCard(
                assignment: assignment,
                isSaving: _savingId == assignment.id,
                onAction: _handleAction,
                onCall: _callCustomer,
                onNavigate: _navigate,
              ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppConstants.primaryLight,
          child: Icon(
            Icons.delivery_dining_rounded,
            color: AppConstants.primaryDark,
            size: 38,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile?.name ?? 'Delivery staff',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        Text(
          profile?.email ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppConstants.textMuted),
        ),
        if (profile?.phone.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            profile!.phone,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
        const SizedBox(height: 22),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.badge_outlined, color: AppConstants.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Store delivery staff are monthly salaried. This app tracks assigned orders and customer COD only; it does not calculate staff pay or per-delivery earnings.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    DeliveryAssignment assignment,
    String action,
  ) async {
    switch (action) {
      case 'DECLINED':
        await _decline(assignment);
        return;
      case 'FAILED':
        await _reportFailure(assignment);
        return;
      case 'DELIVERED':
        await _completeDelivery(assignment);
        return;
      default:
        await _update(assignment, action);
    }
  }
}

class _AvailabilityCard extends StatelessWidget {
  final String name;
  final bool isAvailable;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  const _AvailabilityCard({
    required this.name,
    required this.isAvailable,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
      decoration: BoxDecoration(
        color: AppConstants.primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAvailable ? 'Available for assignments' : 'Off duty',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isSaving)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Switch.adaptive(
              value: isAvailable,
              activeTrackColor: Colors.white.withValues(alpha: 0.35),
              activeThumbColor: Colors.white,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 102),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppConstants.primary, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              color: AppConstants.textMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashDueCard extends StatelessWidget {
  final double amount;

  const _CashDueCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF2D9A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFF9B5B08)),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Customer cash to collect',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF7C4604),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashHandoverDueCard extends StatelessWidget {
  final double amount;

  const _CashHandoverDueCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFC8DCC1)),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined,
              color: AppConstants.primaryDark),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Customer COD to hand to store',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppConstants.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final DeliveryAssignment assignment;
  final bool isSaving;
  final Future<void> Function(DeliveryAssignment, String) onAction;
  final Future<void> Function(String) onCall;
  final Future<void> Function(DeliveryOrder) onNavigate;

  const _AssignmentCard({
    required this.assignment,
    required this.isSaving,
    required this.onAction,
    required this.onCall,
    required this.onNavigate,
  });

  String get _statusLabel => switch (assignment.status) {
        'ASSIGNED' => 'NEW ASSIGNMENT',
        'ACCEPTED' => 'READY FOR PICKUP',
        'PICKED_UP' => 'PICKED UP',
        'OUT_FOR_DELIVERY' => 'ON THE WAY',
        'DELIVERED' => 'DELIVERED',
        'DECLINED' => 'DECLINED · STORE NOTIFIED',
        'FAILED' => 'FAILED · STORE NOTIFIED',
        'CANCELLED' => 'CANCELLED · CONTACT STORE',
        _ => assignment.status,
      };

  @override
  Widget build(BuildContext context) {
    final order = assignment.order;
    final actions = _actionsFor(assignment.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppConstants.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.customerName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              order.address.isEmpty
                  ? 'No delivery address saved'
                  : order.address,
              style: TextStyle(
                fontSize: 13,
                color: AppConstants.textMuted,
                height: 1.35,
              ),
            ),
            if (order.customerPhone.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              _InfoLine(
                icon: Icons.call_outlined,
                text: order.customerPhone,
              ),
            ],
            if (order.instructions.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.sticky_note_2_outlined,
                text: order.instructions,
              ),
            ],
            if (order.latitude != null && order.longitude != null) ...[
              const SizedBox(height: 7),
              _InfoLine(
                icon: Icons.my_location_outlined,
                text: 'Pin: ${order.latitude!.toStringAsFixed(5)}, '
                    '${order.longitude!.toStringAsFixed(5)}',
              ),
            ],
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 9),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: AppConstants.primary,
                        size: 6,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '× ${item.quantity}',
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assignment.status == 'DELIVERED' &&
                              assignment.cashCollected > 0.009
                          ? 'COD collected'
                          : order.cashDue > 0.009
                              ? 'COD to collect'
                              : order.paymentMethod != 'COD' &&
                                      order.paymentStatus != 'COMPLETED'
                                  ? 'Online payment · confirm with store'
                                  : 'Paid online · Rs. 0 COD due',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    'Rs. ${(assignment.status == 'DELIVERED' ? assignment.cashCollected : order.cashDue).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (assignment.status == 'DELIVERED' &&
                assignment.cashCollected > 0.009) ...[
              const SizedBox(height: 6),
              Text(
                assignment.cashHandedOverAt == null
                    ? 'Cash handover to store is still pending.'
                    : 'Store recorded this cash as received.',
                style: TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: order.customerPhone.isEmpty
                      ? null
                      : () => onCall(order.customerPhone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      order.address.isEmpty ? null : () => onNavigate(order),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Navigate'),
                ),
              ],
            ),
            if (assignment.status == 'DECLINED' ||
                assignment.status == 'FAILED' ||
                assignment.status == 'CANCELLED') ...[
              const SizedBox(height: 8),
              const _ErrorNotice(
                message:
                    'The store has been notified. Wait for reassignment or further instructions.',
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 7),
              if (isSaving)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onAction(assignment, actions.first),
                      icon: Icon(_actionIcon(actions.first)),
                      label: Text(_actionLabel(actions.first)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    if (actions.length > 1) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => onAction(assignment, actions.last),
                        child: Text(_actionLabel(actions.last)),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _actionsFor(String status) => switch (status) {
        'ASSIGNED' => ['ACCEPTED', 'DECLINED'],
        'ACCEPTED' => ['PICKED_UP'],
        'PICKED_UP' => ['OUT_FOR_DELIVERY'],
        'OUT_FOR_DELIVERY' => ['DELIVERED', 'FAILED'],
        _ => const [],
      };

  String _actionLabel(String status) => switch (status) {
        'ACCEPTED' => 'Accept delivery',
        'DECLINED' => 'Decline with reason',
        'PICKED_UP' => 'Confirm package pickup',
        'OUT_FOR_DELIVERY' => 'Start delivery',
        'DELIVERED' => 'Complete delivery',
        'FAILED' => 'Report failed delivery',
        _ => status,
      };

  IconData _actionIcon(String status) => switch (status) {
        'ACCEPTED' => Icons.check_circle_outline_rounded,
        'PICKED_UP' => Icons.inventory_2_outlined,
        'OUT_FOR_DELIVERY' => Icons.navigation_rounded,
        'DELIVERED' => Icons.task_alt_rounded,
        _ => Icons.warning_amber_rounded,
      };
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppConstants.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  final String message;

  const _EmptyDeliveries({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 34,
            color: AppConstants.primary,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorNotice({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9C3D17)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8A3312), fontSize: 12),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ErrorNotice(message: message, onRetry: onRetry),
        ),
      );
}
