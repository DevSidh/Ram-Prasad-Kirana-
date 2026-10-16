import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/store_animation.dart';
import '../../widgets/product_thumbnail.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _translateText(String text) {
    return context.read<AppLanguageProvider?>()?.translate(text) ?? text;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final themeProvider = context.watch<ThemeProvider?>();
    final isDark = themeProvider?.isDarkMode ?? AppConstants.isDarkTheme;
    final items = cart.itemList;

    if (items.isEmpty) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundFor(isDark),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(context.tr('Your Basket')),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          forceMaterialTransparency: true,
        ),
        body: DecoratedBox(
          decoration: _cartBackdrop(isDark),
          child: cart.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cart.syncError != null
                  ? StorePageError(
                      title: 'Basket unavailable',
                      message: cart.syncError!,
                      retryLabel: 'Retry',
                      onRetry: cart.retrySync,
                    )
                  : EmptyState(
                      icon: Icons.shopping_basket_outlined,
                      title: context.tr('Your basket is empty'),
                      message: context.tr(
                        'Browse fresh fruits, vegetables, artisan bakery, and mountain dairy to start shopping.',
                      ),
                    ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundFor(isDark),
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${context.tr('Your Basket')} (${cart.itemCount})'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClearCart(cart),
            tooltip: context.tr('Clear basket'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: _cartBackdrop(isDark),
            ),
          ),
          RefreshIndicator(
            onRefresh: cart.refreshSavedCart,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                bottom: MediaQuery.paddingOf(context).bottom + 190,
              ),
              child: Column(
                children: [
                  if (cart.hasUnavailableItems)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Material(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            context.tr(
                              'Some basket items are no longer available or exceed current stock. Reduce quantities or remove them before checkout.',
                            ),
                            style: TextStyle(
                              color: AppConstants.textDark,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (cart.syncError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Material(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.cloud_off_outlined,
                            color: Colors.red,
                          ),
                          title: Text(
                            cart.syncError!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            tooltip: 'Retry basket sync',
                            onPressed: cart.retrySync,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      context.tr('Delivery fee is a flat Rs. 40.'),
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 12,
                      ),
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
                          return Dismissible(
                            key: ValueKey(
                              'cart-${item.product.id}-${item.isWholesale}',
                            ),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                            ),
                            onDismissed: (_) {
                              cart.removeItem(
                                item.product.id,
                                isWholesale: item.isWholesale,
                              );
                              _showUndoSnackBar(
                                message: '${item.product.name} removed.',
                                actionLabel: _translateText('Undo'),
                                onUndo: () => cart.restoreItem(
                                  item.product,
                                  item.quantity,
                                  isWholesale: item.isWholesale,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppConstants.glassSurfaceFor(
                                  isDark,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppConstants.glassBorderFor(
                                    isDark,
                                  ),
                                ),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    item.product.weight,
                                                    style: TextStyle(
                                                        color: AppConstants
                                                            .textMuted,
                                                        fontSize: 11),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${AppConstants.currencySymbol}${item.unitPrice.toInt()}${item.isWholesale ? ' / bulk unit' : ''}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppConstants
                                                            .primary),
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
                                            maxQuantity: item.product.stock
                                                .clamp(0, 100)
                                                .toInt(),
                                            onDecrease: () => _decreaseQuantity(
                                              cart,
                                              item.product,
                                              item.quantity,
                                              isWholesale: item.isWholesale,
                                            ),
                                            onIncrease: () =>
                                                cart.updateQuantity(
                                              item.product.id,
                                              item.quantity + 1,
                                              isWholesale: item.isWholesale,
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
                                                    color:
                                                        AppConstants.textMuted,
                                                    fontSize: 11),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${AppConstants.currencySymbol}${item.unitPrice.toInt()}${item.isWholesale ? ' / bulk unit' : ''}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color:
                                                        AppConstants.primary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _QuantityStepper(
                                          productName: item.product.name,
                                          quantity: item.quantity,
                                          maxQuantity: item.product.stock
                                              .clamp(0, 100)
                                              .toInt(),
                                          onDecrease: () => _decreaseQuantity(
                                            cart,
                                            item.product,
                                            item.quantity,
                                            isWholesale: item.isWholesale,
                                          ),
                                          onIncrease: () => cart.updateQuantity(
                                            item.product.id,
                                            item.quantity + 1,
                                            isWholesale: item.isWholesale,
                                          ),
                                        ),
                                      ],
                                    ),
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
                        color: AppConstants.glassSurfaceFor(
                          isDark,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppConstants.glassBorderFor(
                            isDark,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildBillRow('Basket Subtotal',
                              '${AppConstants.currencySymbol}${cart.subtotal.toInt()}'),
                          const SizedBox(height: 8),
                          _buildBillRow(
                            'Delivery Fee',
                            '${AppConstants.currencySymbol}${cart.deliveryFee.toInt()}',
                          ),
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
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 96,
            child: _buildCheckoutButton(cart),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(CartProvider cart) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        key: const ValueKey('cart-proceed-checkout'),
        onPressed: cart.isLoading || cart.hasUnavailableItems
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: cart.isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppConstants.primaryForeground,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Restoring saved basket…'),
                ],
              )
            : Row(
                children: [
                  Text(
                    '${AppConstants.currencySymbol}${cart.grandTotal.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppConstants.primaryForeground),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            context.tr('Proceed to Checkout'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppConstants.primaryForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppConstants.primaryForeground,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showUndoSnackBar({
    required String message,
    required String actionLabel,
    required VoidCallback onUndo,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: actionLabel,
            onPressed: onUndo,
          ),
        ),
      );
    });
  }

  void _decreaseQuantity(CartProvider cart, Product product, int quantity,
      {bool isWholesale = false}) {
    final minimumQuantity = isWholesale ? product.wholesaleMinimumQuantity : 1;
    if (quantity > minimumQuantity) {
      cart.updateQuantity(
        product.id,
        quantity - 1,
        isWholesale: isWholesale,
      );
      return;
    }

    final undoLabel = _translateText('Undo');
    cart.removeItem(product.id, isWholesale: isWholesale);
    _showUndoSnackBar(
      message: isWholesale
          ? '${product.name} wholesale pack removed from your basket.'
          : '${product.name} removed from your basket.',
      actionLabel: undoLabel,
      onUndo: () => cart.restoreItem(
        product,
        quantity,
        isWholesale: isWholesale,
      ),
    );
  }

  void _clearCartWithUndo(CartProvider cart) {
    final previousItems = cart.itemList;
    if (previousItems.isEmpty) return;

    final undoLabel = _translateText('Undo');
    cart.clearCart();
    _showUndoSnackBar(
      message: 'Basket cleared.',
      actionLabel: undoLabel,
      onUndo: () {
        for (final item in previousItems) {
          cart.restoreItem(
            item.product,
            item.quantity,
            isWholesale: item.isWholesale,
          );
        }
      },
    );
  }

  Future<void> _confirmClearCart(CartProvider cart) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Clear basket?')),
        content: Text(
          context.tr('Remove all items from your basket?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Clear basket')),
          ),
        ],
      ),
    );
    if (shouldClear == true && mounted) _clearCartWithUndo(cart);
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
  final int maxQuantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.productName,
    required this.quantity,
    required this.maxQuantity,
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
            icon: Icon(
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppConstants.primaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add one $productName',
            onPressed: quantity >= maxQuantity ? null : onIncrease,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            icon: Icon(
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

BoxDecoration _cartBackdrop(bool isDark) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF101812),
              Color(0xFF080A09),
              Color(0xFF0D110E),
            ]
          : const [
              Color(0xFFE2F4E7),
              Color(0xFFF4FAF5),
              Color(0xFFEAF6ED),
            ],
    ),
  );
}
