import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import 'customer_menu_settings_screen.dart';

class AdminCustomersScreen extends StatefulWidget {
  final ApiService api;

  const AdminCustomersScreen({super.key, required this.api});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _searchController = TextEditingController();
  AdminCustomerPage? _page;
  List<AdminCustomerRemovalRecord> _removalHistory = const [];
  String? _error;
  String? _removalHistoryError;
  bool _loading = true;
  bool _loadingRemovalHistory = false;
  bool _removalHistoryLoaded = false;
  int _pageNumber = 1;

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
    });
    try {
      final page = await _adminApi.getCustomers(
        page: _pageNumber,
        search: _searchController.text,
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
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

  Future<void> _loadRemovalHistory() async {
    if (_loadingRemovalHistory) return;
    setState(() {
      _loadingRemovalHistory = true;
      _removalHistoryError = null;
    });
    try {
      final records = await _adminApi.getCustomerRemovalHistory();
      if (!mounted) return;
      setState(() {
        _removalHistory = records;
        _removalHistoryLoaded = true;
        _loadingRemovalHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _removalHistoryError = error.toString().replaceFirst('Exception: ', '');
        _loadingRemovalHistory = false;
      });
    }
  }

  Future<void> _editCustomer(AdminCustomer customer) async {
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone);
    final formKey = GlobalKey<FormState>();
    var isActive = customer.isActive;
    final update = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${customer.profileId}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter a name.',
                  ),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      return phone.isEmpty || phone.length >= 7
                          ? null
                          : 'Enter at least 7 characters or leave blank.';
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Customer account active'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'isActive': isActive,
                });
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    if (update == null || !mounted) return;

    try {
      await _adminApi.updateCustomer(customer.id, update);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details updated.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openCustomerMenuSettings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomerMenuSettingsScreen(api: widget.api),
      ),
    );
  }

  Future<void> _removeCustomer(AdminCustomer customer) async {
    final confirmedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var phrase = '';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Remove customer?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This anonymizes ${customer.name} and releases their email and phone for a new account. Orders, item lines, payments, and fulfillment history will be preserved.',
                ),
                const SizedBox(height: 12),
                const Text('Type REMOVE USER to continue.'),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('remove-customer-confirmation'),
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation phrase',
                  ),
                  onChanged: (value) => setDialogState(() => phrase = value),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: phrase == 'REMOVE USER'
                        ? () => Navigator.pop(dialogContext, phrase)
                        : null,
                    child: const Text('Remove customer'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || confirmedText != 'REMOVE USER') return;

    final originalPage = _page;
    if (originalPage != null) {
      setState(() {
        _page = AdminCustomerPage(
          customers: originalPage.customers
              .where((item) => item.id != customer.id)
              .toList(),
          pagination: AdminPagination(
            page: originalPage.pagination.page,
            pageSize: originalPage.pagination.pageSize,
            total:
                (originalPage.pagination.total - 1).clamp(0, 1 << 31).toInt(),
          ),
        );
      });
    }
    try {
      await _adminApi.removeCustomer(
        customer.id,
        confirmation: 'REMOVE USER',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer removed; historical orders were preserved.'),
        ),
      );
      _removalHistoryLoaded = false;
      await _loadRemovalHistory();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _page = originalPage;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _page?.customers ?? const <AdminCustomer>[];
    final pagination = _page?.pagination;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            'Customers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer contact details, saved addresses and recent orders.',
            style: TextStyle(color: AppConstants.textMuted),
          ),
          ExpansionTile(
            key: const ValueKey('customer-removal-history'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Customer removal history'),
            subtitle:
                const Text('Review removed profile IDs and audit details'),
            onExpansionChanged: (expanded) {
              if (expanded && !_removalHistoryLoaded) {
                _loadRemovalHistory();
              }
            },
            children: [
              if (_loadingRemovalHistory)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (_removalHistoryError != null)
                ListTile(
                  title: Text(_removalHistoryError!),
                  trailing: IconButton(
                    tooltip: 'Retry removal history',
                    onPressed: _loadRemovalHistory,
                    icon: const Icon(Icons.refresh),
                  ),
                )
              else if (_removalHistory.isEmpty)
                const ListTile(
                  title: Text('No customers have been removed.'),
                )
              else
                ..._removalHistory.map((record) {
                  final removedAt = record.removedAt.toLocal();
                  final time =
                      TimeOfDay.fromDateTime(removedAt).format(context);
                  return ListTile(
                    leading: const Icon(Icons.person_remove_alt_1_outlined),
                    title: Text('Profile ${record.profileId}'),
                    subtitle: Text(
                      'Removed ${MaterialLocalizations.of(context).formatMediumDate(removedAt)} at $time by ${record.removedByName} (${record.removedByProfileId})',
                    ),
                  );
                }),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openCustomerMenuSettings,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Customer menu controls'),
            ),
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
              hintText: 'Search name, phone, email or order ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search customers',
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            _CustomerNotice(message: _error!),
          ],
          const SizedBox(height: 10),
          if (_loading && _page == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (customers.isEmpty)
            const _EmptyCustomers()
          else
            ...customers.map(
              (customer) => _CustomerCard(
                customer,
                onRemove: () => _removeCustomer(customer),
                onEdit: () => _editCustomer(customer),
              ),
            ),
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
}

class _CustomerCard extends StatelessWidget {
  final AdminCustomer customer;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _CustomerCard(
    this.customer, {
    required this.onRemove,
    required this.onEdit,
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
        leading: CircleAvatar(
          backgroundColor: AppConstants.primaryLight,
          child: Text(
            customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
            style: TextStyle(
              color: AppConstants.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (customer.profileId.isNotEmpty) customer.profileId,
            customer.phone,
            customer.email,
            '${customer.orderCount} orders',
          ].where((value) => value.trim().isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, height: 1.4),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _CustomerField(
            label: 'Order value (excluding cancelled)',
            value: 'Rs. ${customer.orderValue.toStringAsFixed(0)}',
          ),
          _CustomerField(
            label: 'Account',
            value: customer.isActive ? 'Active' : 'Suspended',
          ),
          if (customer.profileId.isNotEmpty)
            _CustomerField(
              label: 'Customer ID',
              value: customer.profileId,
            ),
          if (customer.createdAt != null)
            _CustomerField(
              label: 'Customer since',
              value: _formatCreatedAt(context, customer.createdAt!),
            ),
          if (customer.addresses.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Saved addresses',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            for (final address in customer.addresses)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    address['label']?.toString(),
                    address['addressLine1']?.toString(),
                    address['addressLine2']?.toString(),
                    address['city']?.toString(),
                    address['district']?.toString(),
                    address['province']?.toString(),
                  ]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          if (customer.recentOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Recent orders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            for (final order in customer.recentOrders)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order['orderNumber']} · ${order['status']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Rs. ${_number(order['total']).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit customer'),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Remove customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCreatedAt(BuildContext context, String value) {
    final createdAt = DateTime.tryParse(value)?.toLocal();
    if (createdAt == null) return value;
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(createdAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt))}';
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CustomerField extends StatelessWidget {
  final String label;
  final String value;

  const _CustomerField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CustomerNotice extends StatelessWidget {
  final String message;

  const _CustomerNotice({required this.message});

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

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 42, color: AppConstants.primary),
          const SizedBox(height: 12),
          const Text('No customers found',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Registered customers will appear here.',
            style: TextStyle(color: AppConstants.textMuted),
          ),
        ],
      ),
    );
  }
}
