import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../admin/admin_billing_screen.dart';
import '../auth/login_screen.dart';

class BillingShell extends StatefulWidget {
  const BillingShell({super.key});

  @override
  State<BillingShell> createState() => _BillingShellState();
}

class _BillingShellState extends State<BillingShell> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of the billing counter?'),
        content: const Text('You will need to sign in again to continue.'),
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
    setState(() => _signingOut = true);
    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(isBillingLogin: true),
        ),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.point_of_sale_rounded,
                color: AppConstants.primary),
            const SizedBox(width: 10),
            const Text('Billing Counter'),
            if (staff != null) ...[
              const SizedBox(width: 14),
              Text(
                staff.fullName,
                style: TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdminBillingScreen(
          api: context.read<ApiService>(),
          isBillingStaff: true,
        ),
      ),
    );
  }
}
