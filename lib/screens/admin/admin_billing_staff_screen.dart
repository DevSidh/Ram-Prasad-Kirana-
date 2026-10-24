import 'package:flutter/material.dart';

import '../../models/pos_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';

class AdminBillingStaffScreen extends StatefulWidget {
  const AdminBillingStaffScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminBillingStaffScreen> createState() =>
      _AdminBillingStaffScreenState();
}

class _AdminBillingStaffScreenState extends State<AdminBillingStaffScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _searchController = TextEditingController();
  List<BillingStaffAccount> _staff = const [];
  bool _loading = true;
  String? _error;
  String? _workingUserId;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await _adminApi.getBillingStaff(
        query: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _staff = staff;
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

  Future<void> _changeRole(BillingStaffAccount account) async {
    final promoting = account.role != 'BILLING_STAFF';
    final targetRole = promoting ? 'BILLING_STAFF' : 'CUSTOMER';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            promoting ? 'Grant billing access?' : 'Remove billing access?'),
        content: Text(
          promoting
              ? '${account.name} will be able to use the billing counter.'
              : '${account.name} will lose billing-counter access and return to a customer account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(promoting ? 'Grant access' : 'Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _workingUserId = account.id;
      _error = null;
    });
    try {
      await _adminApi.setBillingStaffRole(
        userId: account.id,
        role: targetRole,
      );
      await _loadStaff();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing staff access'),
      ),
      body: AdminGradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 30, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Only active, verified accounts can be granted billing access. '
                    'Changes revoke the account’s current session.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _loadStaff(),
                          decoration: const InputDecoration(
                            labelText: 'Search verified users by name or email',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _loading ? null : _loadStaff,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppBanner(
                      message: _error!,
                      variant: AppStatusVariant.error,
                      icon: Icons.error_outline_rounded,
                      trailing: TextButton(
                        onPressed: _loading ? null : _loadStaff,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _staff.isEmpty
                            ? const Center(
                                child: Text('No matching verified accounts.'),
                              )
                            : ListView.separated(
                                itemCount: _staff.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final account = _staff[index];
                                  final isBillingStaff =
                                      account.role == 'BILLING_STAFF';
                                  final canPromote =
                                      account.isActive && account.emailVerified;
                                  final working = _workingUserId == account.id;
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            AppColors.thumbnailBlue,
                                        foregroundColor: AppColors.primary,
                                        child: Icon(
                                          isBillingStaff
                                              ? Icons.point_of_sale_rounded
                                              : Icons.person_outline_rounded,
                                        ),
                                      ),
                                      title: Text(account.name),
                                      subtitle: Text(
                                        '${account.email} · '
                                        '${account.isActive ? 'Active' : 'Inactive'}',
                                      ),
                                      trailing: FilledButton(
                                        onPressed: working ||
                                                (!isBillingStaff && !canPromote)
                                            ? null
                                            : () => _changeRole(account),
                                        child: working
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                isBillingStaff
                                                    ? 'Remove access'
                                                    : 'Grant access',
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
