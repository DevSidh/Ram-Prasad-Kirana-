import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../core/constants.dart';
import '../../core/order_time.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/order_invoice_service.dart';
import 'order_tracking_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_product_rating_section.dart';
import '../../widgets/store_animation.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const _invoiceChannel = MethodChannel('faststore/invoices');
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
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Invoice PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'download'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'share'),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print or share'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _invoiceOrderId = order.id);
    final messenger = ScaffoldMessenger.of(context);
    final isAndroidDownload = action == 'download' &&
        Theme.of(context).platform == TargetPlatform.android;
    final progressSnackBar = isAndroidDownload
        ? messenger.showSnackBar(
            const SnackBar(
              duration: Duration(minutes: 2),
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Downloading invoice…'),
                ],
              ),
            ),
          )
        : null;
    try {
      final bytes = await OrderInvoiceService.createPdf(order);
      if (!mounted) return;
      final safeOrderNumber =
          order.orderNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final filename = 'Ram-Prasad-Invoice-$safeOrderNumber.pdf';
      if (isAndroidDownload) {
        final savedPath = await _invoiceChannel.invokeMethod<String>(
          'savePdf',
          {'filename': filename, 'bytes': bytes},
        );
        if (savedPath == null || savedPath.trim().isEmpty) {
          throw StateError('The invoice PDF was not saved.');
        }
        if (!mounted) return;
        progressSnackBar?.close();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            backgroundColor: Theme.of(context).colorScheme.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Your bill has been downloaded',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  savedPath,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      } else if (action == 'download') {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => bytes,
        );
      }
    } catch (error) {
      if (!mounted) return;
      progressSnackBar?.close();
      messenger.showSnackBar(
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 13,
                    color: AppConstants.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Ordered ${formatOrderPlacedAt(ord.createdAt)}',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                'To: ${ord.address.street}',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (ord.items.isNotEmpty &&
                  ord.status != 'CANCELLED' &&
                  (ord.paymentStatus == 'COMPLETED' ||
                      ord.status == 'DELIVERED')) ...[
                const SizedBox(height: 12),
                OrderProductRatingSection(
                  items: ord.items,
                  title: 'Rate products from this order',
                ),
              ],
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
