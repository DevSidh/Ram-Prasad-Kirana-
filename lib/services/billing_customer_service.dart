import '../models/admin_models.dart';
import 'billing_excel_export_service.dart';
import 'offline_pos_store.dart';

/// Local billing customers are reusable without creating an online account.
class BillingCustomerService {
  static String phoneKey(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 13 && digits.startsWith('977')
        ? digits.substring(3)
        : digits;
  }

  static List<AdminCustomer> merge(Iterable<AdminCustomer> customers) {
    final result = <String, AdminCustomer>{};
    for (final customer in customers) {
      if (!customer.isActive || customer.name.trim().isEmpty) continue;
      final phone = phoneKey(customer.phone);
      final key = phone.isEmpty
          ? 'name:${customer.name.trim().toLowerCase()}'
          : 'phone:$phone';
      result.putIfAbsent(key, () => customer);
    }
    return result.values.toList();
  }

  static Future<List<AdminCustomer>> readLocal(OfflinePosStore store) async {
    final customers = <AdminCustomer>[];
    try {
      customers.addAll(await BillingExcelExportService.readSavedCustomers());
    } catch (_) {/* Local bill files can still supply customer details. */}
    try {
      final bills = await store.readOfflineSales();
      for (final bill in bills) {
        final savedName = bill.customerName?.trim() ?? '';
        final phone = phoneKey(bill.customerPhone ?? '');
        if (savedName.isEmpty && phone.isEmpty) continue;
        final name = savedName.isEmpty ? 'Customer' : savedName;
        customers.add(AdminCustomer(
          id: 'local-customer-${phone.isEmpty ? name.toLowerCase() : phone}',
          profileId: '',
          name: name,
          email: '',
          phone: phone,
          isActive: true,
          createdAt: bill.createdAt.toIso8601String(),
          orderCount: 1,
          orderValue: bill.total,
          addresses: const [],
          recentOrders: const [],
        ));
      }
    } catch (_) {/* A damaged bill must not hide the customer index. */}
    return merge(customers.map((customer) => AdminCustomer(
          id: customer.id.startsWith('local-customer-')
              ? customer.id
              : 'local-customer-${customer.id}',
          profileId: customer.profileId,
          name: customer.name,
          email: customer.email,
          phone: phoneKey(customer.phone),
          isActive: customer.isActive,
          createdAt: customer.createdAt,
          orderCount: customer.orderCount,
          orderValue: customer.orderValue,
          addresses: customer.addresses,
          recentOrders: customer.recentOrders,
        )));
  }
}
