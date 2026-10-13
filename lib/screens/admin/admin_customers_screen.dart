import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

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
  String? _error;
  bool _loading = true;
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
            ...customers.map(_CustomerCard.new),
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
                  onPressed: _pageNumber * pagination.pageSize >=
                          pagination.total
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

  const _CustomerCard(this.customer);

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
        ],
      ),
    );
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
