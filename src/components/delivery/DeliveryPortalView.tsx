import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { Truck, MapPin, Phone, CheckCircle2, Navigation, DollarSign, Clock, Check } from 'lucide-react';

export const DeliveryPortalView: React.FC = () => {
  const { orders, updateOrderStatus, formatPrice } = useStore();
  const [completedCode, setCompletedCode] = useState<{ [key: string]: string }>({});

  const assignedOrders = orders.filter(
    (o) => o.status === 'out_for_delivery' || o.status === 'packing' || o.status === 'confirmed'
  );

  const handleStartRoute = (orderId: string) => {
    updateOrderStatus(orderId, 'out_for_delivery', 'Rider departed Lalitpur hub, headed to destination.');
  };

  const handleConfirmDelivered = (orderId: string) => {
    updateOrderStatus(orderId, 'delivered', 'Package delivered safely to customer doorstep.');
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Header */}
      <div className="bg-zinc-900 text-white rounded-2xl p-6 mb-8 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-amber-600 flex items-center justify-center font-bold text-lg text-white">
            BT
          </div>
          <div>
            <h1 className="text-xl font-bold font-display">Bikram Thapa</h1>
            <div className="text-xs text-zinc-400 mt-0.5">
              Rider ID: #DR-4481 · Honda CB Shine (BA 89 PA 4521)
            </div>
            <div className="text-[11px] text-amber-400 font-semibold mt-1">
              Active Shift: Ram Prasad General Store Express Dispatch
            </div>
          </div>
        </div>

        <div className="flex items-center gap-6 text-xs text-zinc-300 border-t sm:border-t-0 pt-3 sm:pt-0 border-zinc-800">
          <div>
            <div className="text-lg font-bold font-mono text-white tabular-nums">
              {assignedOrders.length}
            </div>
            <div className="text-zinc-500">Assigned Tasks</div>
          </div>
          <div className="border-l border-zinc-800 pl-6">
            <div className="text-lg font-bold font-mono text-emerald-400 tabular-nums">
              4.9★
            </div>
            <div className="text-zinc-500">Service Rating</div>
          </div>
        </div>
      </div>

      {/* Orders List */}
      <div className="space-y-6">
        <h2 className="text-lg font-bold text-zinc-900">
          Assigned Deliveries ({assignedOrders.length})
        </h2>

        {assignedOrders.length === 0 ? (
          <div className="bg-white rounded-2xl border border-zinc-200 p-12 text-center">
            <CheckCircle2 className="w-12 h-12 mx-auto text-emerald-600 mb-2" />
            <h3 className="font-semibold text-sm text-zinc-900">All Deliveries Complete!</h3>
            <p className="text-xs text-zinc-400 mt-1">Waiting for fresh dispatch batches from the hub.</p>
          </div>
        ) : (
          assignedOrders.map((ord) => (
            <div
              key={ord.id}
              className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs space-y-4"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-zinc-100">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-base text-zinc-900">#{ord.orderNumber}</span>
                    <span className="text-xs font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-purple-50 text-[#5C2D91] border border-purple-200">
                      {ord.status.replace('_', ' ')}
                    </span>
                  </div>
                  <div className="text-xs text-zinc-500 mt-1">
                    Slot: {ord.deliveryTimeSlot.timeWindow} ({ord.deliveryTimeSlot.date})
                  </div>
                </div>

                {/* Payment reminder banner */}
                <div className="p-2.5 rounded-xl border text-xs flex items-center gap-2 bg-zinc-50 border-zinc-200">
                  <DollarSign className="w-4 h-4 text-emerald-700" />
                  <div>
                    <span className="text-zinc-500">Cash Collection: </span>
                    <span className="font-bold text-zinc-900 font-mono tabular-nums">
                      {ord.paymentMethod === 'cod' ? `Collect ${formatPrice(ord.total)}` : 'Prepaid Online'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Destination Address & Call */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 bg-zinc-50 p-4 rounded-xl border border-zinc-100 text-xs">
                <div>
                  <div className="font-bold text-zinc-900 flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-rose-600" />
                    <span>{ord.deliveryAddress.street}</span>
                  </div>
                  <div className="text-zinc-600 mt-1">
                    {ord.deliveryAddress.city}, {ord.deliveryAddress.province}
                  </div>
                  {ord.deliveryAddress.deliveryInstructions && (
                    <div className="mt-2 text-zinc-500 italic bg-white p-2 rounded border border-zinc-200">
                      Instruction: {ord.deliveryAddress.deliveryInstructions}
                    </div>
                  )}
                </div>

                <div className="flex flex-col justify-between">
                  <div>
                    <div className="font-semibold text-zinc-900">{ord.deliveryAddress.fullName}</div>
                    <div className="text-zinc-500">{ord.deliveryAddress.phone}</div>
                  </div>

                  <div className="flex items-center gap-2 mt-3">
                    <a
                      href={`tel:${ord.deliveryAddress.phone}`}
                      className="px-3 py-1.5 bg-zinc-900 hover:bg-zinc-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1 transition-colors"
                    >
                      <Phone className="w-3.5 h-3.5" />
                      <span>Call Customer</span>
                    </a>

                    <a
                      href={`https://maps.google.com/?q=${encodeURIComponent(
                        ord.deliveryAddress.street + ', ' + ord.deliveryAddress.city
                      )}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-3 py-1.5 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1 transition-colors"
                    >
                      <Navigation className="w-3.5 h-3.5" />
                      <span>Directions</span>
                    </a>
                  </div>
                </div>
              </div>

              {/* Items in Tote */}
              <div className="text-xs text-zinc-600">
                <span className="font-semibold text-zinc-900">Tote Contents: </span>
                {ord.items.map((it) => `${it.product.name} (x${it.quantity})`).join(', ')}
              </div>

              {/* Action Buttons */}
              <div className="pt-3 border-t border-zinc-100 flex flex-wrap items-center justify-between gap-3">
                {ord.status !== 'out_for_delivery' ? (
                  <button
                    onClick={() => handleStartRoute(ord.id)}
                    className="px-4 py-2 bg-purple-700 hover:bg-purple-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer shadow-xs"
                  >
                    <Truck className="w-4 h-4" />
                    <span>Depart Hub (Out for Delivery)</span>
                  </button>
                ) : (
                  <div className="flex items-center gap-3 w-full sm:w-auto">
                    <button
                      onClick={() => handleConfirmDelivered(ord.id)}
                      className="px-5 py-2 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer shadow-xs"
                    >
                      <Check className="w-4 h-4" />
                      <span>Mark Delivered to Doorstep</span>
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
