import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { PackageCheck, CheckSquare, Square, Printer, CheckCircle2, Clock, AlertCircle } from 'lucide-react';

export const StaffPackingView: React.FC = () => {
  const { orders, updateOrderStatus, formatPrice } = useStore();
  const [checkedItems, setCheckedItems] = useState<{ [key: string]: boolean }>({});

  const packingOrders = orders.filter(
    (o) => o.status === 'placed' || o.status === 'confirmed' || o.status === 'packing'
  );

  const toggleCheck = (orderId: string, productId: string) => {
    const key = `${orderId}_${productId}`;
    setCheckedItems((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleMarkPacked = (orderId: string) => {
    updateOrderStatus(orderId, 'packing', 'Items packed into temperature-controlled cold tote.');
    alert(`Order ${orderId} marked packed! Notified logistics hub for rider dispatch.`);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      <div className="pb-6 border-b border-zinc-200">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold uppercase tracking-wider text-amber-800 bg-amber-50 px-2 py-0.5 rounded">
            Ram Prasad Store Fulfillment
          </span>
          <span className="text-xs text-zinc-400">Order Packaging Station</span>
        </div>
        <h1 className="text-2xl sm:text-3xl font-display font-bold text-zinc-950 mt-1">
          Store Order Sorting & Packaging Queue
        </h1>
        <p className="text-xs sm:text-sm text-zinc-500 mt-1">
          Verify product quantities, check seal & expiry, and package in sturdy carry bags for riders.
        </p>
      </div>

      <div className="mt-8 space-y-6">
        {packingOrders.length === 0 ? (
          <div className="bg-white rounded-2xl border border-zinc-200 p-12 text-center">
            <CheckCircle2 className="w-12 h-12 mx-auto text-emerald-600 mb-2" />
            <h3 className="font-semibold text-sm text-zinc-900">Packing Queue Clear!</h3>
            <p className="text-xs text-zinc-400 mt-1">All incoming orders have been packed and handed to dispatch.</p>
          </div>
        ) : (
          packingOrders.map((ord) => (
            <div
              key={ord.id}
              className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs space-y-4"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-zinc-100">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-base text-zinc-900">#{ord.orderNumber}</span>
                    <span className="text-xs font-semibold px-2 py-0.5 rounded bg-amber-50 text-amber-800 border border-amber-200">
                      Status: {ord.status.toUpperCase()}
                    </span>
                  </div>
                  <div className="text-xs text-zinc-500 mt-1">
                    Slot: {ord.deliveryTimeSlot.label} · Customer: {ord.customerName}
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => window.print()}
                    className="px-3 py-1.5 text-xs font-semibold text-zinc-700 bg-zinc-100 hover:bg-zinc-200 rounded-lg flex items-center gap-1"
                  >
                    <Printer className="w-3.5 h-3.5" />
                    <span>Packing Slip</span>
                  </button>

                  <button
                    onClick={() => handleMarkPacked(ord.id)}
                    className="px-4 py-1.5 text-xs font-semibold text-white bg-emerald-700 hover:bg-emerald-800 rounded-lg flex items-center gap-1.5 cursor-pointer shadow-xs"
                  >
                    <PackageCheck className="w-3.5 h-3.5" />
                    <span>Confirm Packed & Ready</span>
                  </button>
                </div>
              </div>

              {/* Checklist table */}
              <div className="space-y-2">
                <div className="text-xs font-bold text-zinc-700 uppercase tracking-wider mb-2">
                  Item Packing Checklist ({ord.items.length} items)
                </div>

                {ord.items.map((it) => {
                  const key = `${ord.id}_${it.productId}`;
                  const isChecked = !!checkedItems[key];
                  return (
                    <div
                      key={it.productId}
                      onClick={() => toggleCheck(ord.id, it.productId)}
                      className={`p-3 rounded-xl border flex items-center justify-between text-xs cursor-pointer transition-colors ${
                        isChecked
                          ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                          : 'bg-zinc-50/40 border-zinc-200 hover:bg-zinc-100/50'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        {isChecked ? (
                          <CheckSquare className="w-4 h-4 text-emerald-700 shrink-0" />
                        ) : (
                          <Square className="w-4 h-4 text-zinc-400 shrink-0" />
                        )}
                        <img
                          src={it.product.image}
                          alt={it.product.name}
                          className="w-8 h-8 rounded object-cover"
                        />
                        <div>
                          <span className={`font-semibold ${isChecked ? 'line-through text-zinc-500' : 'text-zinc-900'}`}>
                            {it.product.name}
                          </span>
                          <div className="text-[11px] text-zinc-400">
                            Unit: {it.unit} · Farm: {it.product.origin}
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <span className="font-bold text-sm text-zinc-900 tabular-nums">
                          QTY: {it.quantity}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>

              {ord.deliveryAddress.deliveryInstructions && (
                <div className="p-3 bg-amber-50 rounded-xl text-xs text-amber-900 border border-amber-200/60 flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 text-amber-700 shrink-0" />
                  <span>Packing Note: {ord.deliveryAddress.deliveryInstructions}</span>
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
};
