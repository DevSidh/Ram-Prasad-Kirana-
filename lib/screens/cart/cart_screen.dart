import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_thumbnail.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final items = cart.itemList;

    if (items.isEmpty) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundLight,
        appBar: AppBar(
            title: const Text('Your Basket'), backgroundColor: Colors.white),
        body: const EmptyState(
          icon: Icons.shopping_basket_outlined,
          title: 'Your basket is empty',
          message:
              'Browse fresh fruits, vegetables, artisan bakery, and mountain dairy to start shopping.',
        ),
      );
    }

    final freeDeliveryProgress = (cart.subtotal / 1000.0).clamp(0.0, 1.0);
    final remainingForFree =
        (1000.0 - cart.subtotal).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: Text('Your Basket (${cart.itemCount} items)'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _clearCartWithUndo(cart),
            tooltip: 'Clear basket',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Free Shipping Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppConstants.primaryLight.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          remainingForFree > 0
                              ? 'Add Rs. ${remainingForFree.toInt()} more for FREE Express Delivery'
                              : 'Congratulations! You unlocked Free Delivery!',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(freeDeliveryProgress * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: freeDeliveryProgress,
                    backgroundColor: Colors.white,
                    color: AppConstants.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

            // Item List
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.borderLight),
                      ),
                      child: compact
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    ProductThumbnail(
                                      imageUrl: item.product.imageUrl,
                                      size: 72,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            item.product.weight,
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${AppConstants.currencySymbol}${item.product.price.toInt()}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppConstants.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _QuantityStepper(
                                    productName: item.product.name,
                                    quantity: item.quantity,
                                    onDecrease: () => _decreaseQuantity(
                                      cart,
                                      item.product,
                                      item.quantity,
                                    ),
                                    onIncrease: () => cart.updateQuantity(
                                      item.product.id,
                                      item.quantity + 1,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                ProductThumbnail(
                                  imageUrl: item.product.imageUrl,
                                  size: 72,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.product.weight,
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${AppConstants.currencySymbol}${item.product.price.toInt()}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppConstants.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _QuantityStepper(
                                  productName: item.product.name,
                                  quantity: item.quantity,
                                  onDecrease: () => _decreaseQuantity(
                                    cart,
                                    item.product,
                                    item.quantity,
                                  ),
                                  onIncrease: () => cart.updateQuantity(
                                    item.product.id,
                                    item.quantity + 1,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                );
              },
            ),

            // Bill Breakdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderLight),
                ),
                child: Column(
                  children: [
                    _buildBillRow('Basket Subtotal',
                        '${AppConstants.currencySymbol}${cart.subtotal.toInt()}'),
                    const SizedBox(height: 8),
                    _buildBillRow(
                      'Delivery Fee',
                      cart.deliveryFee == 0
                          ? 'FREE'
                          : '${AppConstants.currencySymbol}${cart.deliveryFee.toInt()}',
                    ),
                    const SizedBox(height: 8),
                    _buildBillRow('Rider Tip',
                        '${AppConstants.currencySymbol}${cart.tip.toInt()}'),
                    const Divider(height: 24),
                    _buildBillRow(
                      'Grand Total',
                      '${AppConstants.currencySymbol}${cart.grandTotal.toInt()}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      // Bottom Checkout Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  '${AppConstants.currencySymbol}${cart.grandTotal.toInt()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Proceed to Checkout',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _decreaseQuantity(
    CartProvider cart,
    Product product,
    int quantity,
  ) {
    if (quantity > 1) {
      cart.updateQuantity(product.id, quantity - 1);
      return;
    }
    cart.removeItem(product.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} removed from your basket.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => cart.addItem(product),
          ),
        ),
      );
  }

  void _clearCartWithUndo(CartProvider cart) {
    final previousItems = cart.itemList;
    if (previousItems.isEmpty) return;
    cart.clearCart();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Basket cleared.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final item in previousItems) {
                cart.addItem(item.product, item.quantity);
              }
            },
          ),
        ),
      );
  }

  Widget _buildBillRow(String label, String value,
      {bool isHighlight = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isHighlight
                  ? AppConstants.primary
                  : (isTotal ? AppConstants.textDark : AppConstants.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight:
                  isTotal || isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? AppConstants.primary
                  : (isTotal ? AppConstants.textDark : AppConstants.textDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final String productName;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.productName,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one $productName',
            onPressed: onDecrease,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.remove,
              size: 18,
              color: AppConstants.primaryDark,
            ),
          ),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppConstants.primaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add one $productName',
            onPressed: onIncrease,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.add,
              size: 18,
              color: AppConstants.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
