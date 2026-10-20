import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../core/constants.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/order_invoice_service.dart';
import 'order_tracking_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/store_animation.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _loading = true;
  String? _error;
  String? _invoiceOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<OrderProvider>().loadOrders();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadInvoice(Order order) async {
    if (_invoiceOrderId != null) return;
    setState(() => _invoiceOrderId = order.id);
    try {
      final bytes = await OrderInvoiceService.createPdf(order);
      if (!mounted) return;
      final safeOrderNumber =
          order.orderNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await Printing.layoutPdf(
        name: 'Ram-Prasad-Invoice-$safeOrderNumber.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create the invoice PDF: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _invoiceOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    context.watch<ThemeProvider?>();
    final orders = orderProvider.orders;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundLight,
        appBar: AppBar(
          title: const Text('My Grocery Orders'),
          backgroundColor: AppConstants.backgroundLight,
          actions: [
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _loading ? null : _loadOrders,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppConstants.primary,
            unselectedLabelColor: AppConstants.textMuted,
            indicatorColor: AppConstants.primary,
            tabs: const [
              Tab(text: 'All Orders'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? StorePageError(
                    title: 'Orders could not load',
                    message: _error!,
                    retryLabel: 'Try again',
                    onRetry: _loadOrders,
                  )
                : orders.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No grocery orders yet',
                        message:
                            'Your past and active deliveries will show up here.',
                      )
                    : TabBarView(
                        children: [
                          _buildOrdersList(context, orders),
                          _buildOrdersList(
                              context,
                              orders
                                  .where((o) =>
                                      o.status != 'DELIVERED' &&
                                      o.status != 'CANCELLED')
                                  .toList()),
                          _buildOrdersList(
                              context,
                              orders
                                  .where((o) => o.status == 'DELIVERED')
                                  .toList()),
                          _buildOrdersList(
                              context,
                              orders
                                  .where((o) => o.status == 'CANCELLED')
                                  .toList()),
                        ],
                      ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<Order> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('No orders in this status',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
      );
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ord = list[index];
        final canCancel =
            const {'PLACED', 'CONFIRMED', 'PROCESSING'}.contains(ord.status);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order #${ord.orderNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ord.status == 'DELIVERED'
                          ? AppConstants.primaryLight
                          : ord.status == 'CANCELLED'
                              ? Colors.red.shade50
                              : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ord.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ord.status == 'DELIVERED'
                            ? AppConstants.primaryDark
                            : ord.status == 'CANCELLED'
                                ? Colors.red.shade800
                                : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${ord.items.length} items · ${AppConstants.currencySymbol}${ord.total.toInt()}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppConstants.textDark),
              ),
              Text(
                'To: ${ord.address.street}',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canCancel)
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancel Order?'),
                                content: const Text(
                                    'Are you sure you want to cancel this order?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Keep')),
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        await orderProvider.cancelOrder(ord.id);
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error.toString().replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Cancel Order',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: Colors.red, fontSize: 12)),
                        )
                      else
                        const SizedBox(),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingScreen(order: ord)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Track Live',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryForeground)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _invoiceOrderId == null
                        ? () => _downloadInvoice(ord)
                        : null,
                    icon: _invoiceOrderId == ord.id
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Download invoice PDF'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
