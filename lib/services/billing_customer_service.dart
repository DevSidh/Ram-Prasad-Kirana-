import '../models/admin_models.dart';
import 'billing_excel_export_service.dart';
import 'offline_pos_store.dart';

/// Local billing customers are reusable without creating an online account.
class BillingCustomerService {
  /// Names are not unique. Only autofill when the exact match identifies one
  /// customer; the picker remains available for customers sharing a name.
  static AdminCustomer? findExact(Iterable<AdminCustomer> customers,
      {required String name, required String phone, bool byName = false}) {
    final normalizedPhone = phoneKey(phone);
    final normalizedName = name.trim().toLowerCase();
    final matches = merge(customers)
        .where((customer) => !byName && normalizedPhone.isNotEmpty
            ? phoneKey(customer.phone) == normalizedPhone
            : normalizedName.isNotEmpty &&
                customer.name.trim().toLowerCase() == normalizedName)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  static String phoneKey(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 13 && digits.startsWith('977')
        ? digits.substring(3)
        : digits;
  }

  static List<AdminCustomer> merge(Iterable<AdminCustomer> customers) {
    final result = <String, AdminCustomer>{};
    for (final customer in customers) {
      if (!customer.isActive ||
          (customer.name.trim().isEmpty && customer.phone.trim().isEmpty)) {
        continue;
      }
      final phone = phoneKey(customer.phone);
      final key = phone.isEmpty
          ? 'name:${customer.name.trim().toLowerCase()}'
          : 'phone:$phone';
      final previous = result[key];
      result[key] = AdminCustomer(
        id: previous?.id ?? customer.id,
        profileId: previous?.profileId ?? customer.profileId,
        name: previous != null &&
                previous.name.trim().isNotEmpty &&
                previous.name != 'Customer'
            ? previous.name
            : (customer.name.trim().isEmpty ? 'Customer' : customer.name),
        email: previous?.email.isNotEmpty == true
            ? previous!.email
            : customer.email,
        phone: phoneKey(previous?.phone ?? customer.phone),
        isActive: true,
        createdAt: previous?.createdAt ?? customer.createdAt,
        orderCount: (previous?.orderCount ?? 0) > customer.orderCount
            ? previous!.orderCount
            : customer.orderCount,
        orderValue: (previous?.orderValue ?? 0) > customer.orderValue
            ? previous!.orderValue
            : customer.orderValue,
        addresses: previous?.addresses.isNotEmpty == true
            ? previous!.addresses
            : customer.addresses,
        recentOrders: previous?.recentOrders ?? customer.recentOrders,
      );
    }
    return result.values.toList();
  }

  static Future<List<AdminCustomer>> readLocal(OfflinePosStore store,
      {Future<List<AdminCustomer>> Function()? loadSavedCustomers}) async {
    final customers = <AdminCustomer>[];
    final syncedCustomerIds = <String>{};
    try {
      final saved = await store.readCustomers();
      customers.addAll(saved);
      syncedCustomerIds.addAll(saved
          .where((customer) => !customer.id.startsWith('local-customer-'))
          .map((customer) => customer.id));
    } catch (_) {/* Legacy local sources remain available. */}
    try {
      customers.addAll(await (loadSavedCustomers ??
          BillingExcelExportService.readSavedCustomers)());
    } catch (_) {/* Local bill files can still supply customer details. */}
    try {
      final bills = await store.readOfflineSales();
      final grouped = <String, AdminCustomer>{};
      for (final bill in bills) {
        final savedName = bill.customerName?.trim() ?? '';
        final phone = phoneKey(bill.customerPhone ?? '');
        if (savedName.isEmpty && phone.isEmpty) continue;
        final name = savedName.isEmpty ? 'Customer' : savedName;
        final key = phone.isEmpty ? name.toLowerCase() : phone;
        final previous = grouped[key];
        grouped[key] = AdminCustomer(
          id: 'local-customer-$key',
          profileId: '',
          name: name,
          email: '',
          phone: phone,
          isActive: true,
          createdAt: bill.createdAt.toIso8601String(),
          orderCount: (previous?.orderCount ?? 0) + 1,
          orderValue: (previous?.orderValue ?? 0) + bill.total,
          addresses: const [],
          recentOrders: const [],
        );
      }
      customers.addAll(grouped.values);
    } catch (_) {/* A damaged bill must not hide the customer index. */}
    final merged = merge(customers.map((customer) => AdminCustomer(
          id: syncedCustomerIds.contains(customer.id) ||
                  customer.id.startsWith('local-customer-')
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
    await store.saveCustomers(merged);
    return merged;
  }
}
