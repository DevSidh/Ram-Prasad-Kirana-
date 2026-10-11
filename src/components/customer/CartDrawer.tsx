import React from 'react';
import { useStore } from '../../context/StoreContext';
import { X, Trash2, Plus, Minus, ShoppingBag, ArrowRight, ShieldCheck, Tag } from 'lucide-react';

export const CartDrawer: React.FC = () => {
  const {
    cart,
    cartSubtotal,
    cartCount,
    isCartDrawerOpen,
    setIsCartDrawerOpen,
    updateQuantity,
    removeFromCart,
    clearCart,
    formatPrice,
    setActivePage,
  } = useStore();

  if (!isCartDrawerOpen) return null;

  const FREE_SHIPPING_THRESHOLD = 1000; // Rs. 1000
  const progressPercent = Math.min(100, (cartSubtotal / FREE_SHIPPING_THRESHOLD) * 100);
  const remainingForFreeShipping = Math.max(0, FREE_SHIPPING_THRESHOLD - cartSubtotal);

  const getItemKey = (item: typeof cart[0]) => {
    return item.selectedVariant ? `${item.productId}__${item.selectedVariant}` : item.productId;
  };

  const handleProceedToCheckout = () => {
    setIsCartDrawerOpen(false);
    setActivePage('checkout');
  };

  return (
    <div
      className="fixed inset-0 z-50 overflow-hidden bg-zinc-950/60 backdrop-blur-xs animate-in fade-in duration-200"
      onClick={() => setIsCartDrawerOpen(false)}
    >
      <div className="absolute inset-y-0 right-0 max-w-full flex pl-10">
        <div
          className="w-screen max-w-md bg-white shadow-2xl flex flex-col justify-between"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="p-4 sm:p-5 border-b border-zinc-200 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <ShoppingBag className="w-5 h-5 text-amber-700" />
              <h2 className="font-display font-bold text-lg text-zinc-950">
                Your Shopping Bag
              </h2>
              <span className="text-xs font-semibold text-zinc-500 tabular-nums">
                ({cartCount} items)
              </span>
            </div>

            <button
              onClick={() => setIsCartDrawerOpen(false)}
              className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-700 hover:bg-zinc-100 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Free Shipping Progress Meter */}
          <div className="px-5 py-3 bg-amber-50/70 border-b border-amber-200/60">
            <div className="flex items-center justify-between text-xs text-amber-950 mb-1.5 font-medium">
              <span>
                {remainingForFreeShipping > 0
                  ? `Add ${formatPrice(remainingForFreeShipping)} more for FREE Express Delivery!`
                  : '🎉 Congratulations! You unlocked Free Delivery!'}
              </span>
              <span className="text-[11px] text-amber-800 font-bold tabular-nums">
                {Math.round(progressPercent)}%
              </span>
            </div>
            <div className="w-full h-1.5 bg-amber-200/80 rounded-full overflow-hidden">
              <div
                className="h-full bg-amber-600 rounded-full transition-all duration-300"
                style={{ width: `${progressPercent}%` }}
              />
            </div>
          </div>

          {/* Basket Items List */}
          <div className="flex-1 overflow-y-auto p-5 divide-y divide-zinc-100">
            {cart.length === 0 ? (
              <div className="h-full flex flex-col items-center justify-center text-center py-12">
                <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center text-zinc-400 mb-4">
                  <ShoppingBag className="w-8 h-8" />
                </div>
                <h3 className="text-base font-semibold text-zinc-900">Your shopping bag is empty</h3>
                <p className="text-xs text-zinc-500 max-w-xs mt-1">
                  Explore everyday groceries, stationery notebooks, cleaning detergents, toiletries, and LED bulbs.
                </p>
                <button
                  onClick={() => {
                    setIsCartDrawerOpen(false);
                    setActivePage('market');
                  }}
                  className="mt-5 px-5 py-2.5 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-bold cursor-pointer"
                >
                  Start Shopping
                </button>
              </div>
            ) : (
              cart.map((item) => {
                const itemKey = getItemKey(item);
                const unitPrice = item.variantPrice !== undefined ? item.variantPrice : item.product.price;
                const lineTotal = unitPrice * item.quantity;

                return (
                  <div key={itemKey} className="py-4 flex gap-3.5 items-start">
                    <img
                      src={item.product.image}
                      alt={item.product.name}
                      referrerPolicy="no-referrer"
                      className="w-16 h-16 rounded-lg object-cover bg-zinc-50 shrink-0 border border-zinc-100"
                    />

                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <h4 className="text-xs font-semibold text-zinc-900 line-clamp-2">
                            {item.product.name}
                          </h4>
                          {item.selectedVariant && (
                            <span className="inline-block mt-0.5 text-[10px] font-bold text-amber-800 bg-amber-100 px-1.5 py-0.2 rounded">
                              Option: {item.selectedVariant}
                            </span>
                          )}
                        </div>
                        <button
                          onClick={() => removeFromCart(itemKey)}
                          className="text-zinc-400 hover:text-rose-600 transition-colors shrink-0 p-1"
                          title="Remove item"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>

                      <div className="text-[11px] text-zinc-500 mt-0.5">{item.unit}</div>

                      <div className="flex items-center justify-between mt-3">
                        <div className="flex items-center border border-zinc-200 rounded-lg bg-zinc-50">
                          <button
                            type="button"
                            onClick={() => updateQuantity(itemKey, item.quantity - 1)}
                            className="w-6 h-6 flex items-center justify-center text-zinc-600 hover:text-zinc-900"
                          >
                            <Minus className="w-3 h-3" />
                          </button>
                          <span className="w-6 text-center text-xs font-bold text-zinc-900 tabular-nums">
                            {item.quantity}
                          </span>
                          <button
                            type="button"
                            disabled={item.quantity >= item.product.stock}
                            onClick={() => updateQuantity(itemKey, item.quantity + 1)}
                            className="w-6 h-6 flex items-center justify-center text-zinc-600 hover:text-zinc-900 disabled:opacity-30"
                          >
                            <Plus className="w-3 h-3" />
                          </button>
                        </div>

                        <div className="text-right">
                          <div className="text-xs font-bold text-zinc-950 tabular-nums font-mono">
                            {formatPrice(lineTotal)}
                          </div>
                          {item.quantity > 1 && (
                            <div className="text-[10px] text-zinc-400 tabular-nums font-mono">
                              {formatPrice(unitPrice)} each
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Footer Checkout Actions */}
          {cart.length > 0 && (
            <div className="p-5 border-t border-zinc-200 bg-zinc-50/50 space-y-3">
              <div className="space-y-1.5 text-xs text-zinc-600">
                <div className="flex justify-between">
                  <span>Subtotal</span>
                  <span className="font-semibold text-zinc-900 tabular-nums font-mono">
                    {formatPrice(cartSubtotal)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Neighborhood Delivery</span>
                  <span>
                    {remainingForFreeShipping === 0 ? (
                      <strong className="text-emerald-700 font-bold uppercase text-[11px]">Free</strong>
                    ) : (
                      <span className="font-mono">Rs. 40</span>
                    )}
                  </span>
                </div>
              </div>

              <div className="pt-2 border-t border-zinc-200 flex items-baseline justify-between">
                <div>
                  <div className="text-xs font-semibold text-zinc-900">Estimated Total</div>
                  <div className="text-[10px] text-zinc-400">All local taxes included</div>
                </div>
                <div className="text-lg font-black text-zinc-950 tabular-nums font-mono">
                  {formatPrice(cartSubtotal + (remainingForFreeShipping === 0 ? 0 : 40))}
                </div>
              </div>

              <div className="pt-2 space-y-2">
                <button
                  type="button"
                  onClick={handleProceedToCheckout}
                  className="w-full py-3 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-colors shadow-xs cursor-pointer"
                >
                  <span>Proceed to Express Checkout</span>
                  <ArrowRight className="w-4 h-4" />
                </button>

                <div className="flex items-center justify-between text-[11px] text-zinc-500 pt-1">
                  <span className="flex items-center gap-1">
                    <ShieldCheck className="w-3.5 h-3.5 text-emerald-700" />
                    <span>COD, Khalti & eSewa accepted</span>
                  </span>
                  <button
                    onClick={clearCart}
                    className="text-zinc-400 hover:text-rose-600 transition-colors"
                  >
                    Clear Bag
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
