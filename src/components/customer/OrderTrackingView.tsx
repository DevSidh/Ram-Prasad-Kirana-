import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import {
  CheckCircle2,
  Clock,
  Package,
  Truck,
  MapPin,
  Phone,
  Printer,
  RotateCcw,
  AlertCircle,
  HelpCircle,
  ShieldCheck,
  ChevronRight,
} from 'lucide-react';

export const OrderTrackingView: React.FC = () => {
  const { orders, activeOrderId, setActiveOrderId, formatPrice, addToCart, setActivePage } = useStore();
  const [showSupportModal, setShowSupportModal] = useState(false);

  const activeOrder = orders.find((o) => o.id === activeOrderId) || orders[0];

  if (!activeOrder) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <Package className="w-12 h-12 mx-auto text-zinc-300 mb-3" />
        <h2 className="text-xl font-bold text-zinc-900">No active deliveries found</h2>
        <p className="text-xs text-zinc-500 mt-1">Place an order to track live doorstep delivery.</p>
        <button
          onClick={() => setActivePage('market')}
          className="mt-4 px-4 py-2 bg-amber-600 text-white rounded-lg text-xs font-bold"
        >
          Browse Store Catalog
        </button>
      </div>
    );
  }

  const steps = [
    { key: 'placed', label: 'Order Placed', desc: 'Order received & logged' },
    { key: 'confirmed', label: 'Confirmed', desc: 'Ram Prasad counter verified' },
    { key: 'packing', label: 'Items Packed', desc: 'Verified & packaged securely' },
    { key: 'out_for_delivery', label: 'Out for Delivery', desc: 'Rider en route to you' },
    { key: 'delivered', label: 'Delivered', desc: 'Handed over at doorstep' },
  ];

  const getStepIndex = (status: string) => {
    switch (status) {
      case 'placed':
        return 0;
      case 'confirmed':
        return 1;
      case 'packing':
        return 2;
      case 'out_for_delivery':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  };

  const currentStepIndex = getStepIndex(activeOrder.status);

  const handleReorder = () => {
    activeOrder.items.forEach((item) => {
      addToCart(item.product, item.quantity, item.unit);
    });
    setActivePage('checkout');
  };

  const handlePrintInvoice = () => {
    window.print();
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-zinc-200">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded">
              Order #{activeOrder.orderNumber}
            </span>
            <span className="text-xs text-zinc-500">
              Placed {new Date(activeOrder.createdAt).toLocaleDateString()}
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-zinc-950 mt-1">
            Live Order Tracking
          </h1>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowSupportModal(true)}
            className="px-3 py-2 text-xs font-semibold text-zinc-700 bg-zinc-100 hover:bg-zinc-200 rounded-lg flex items-center gap-1.5 transition-colors cursor-pointer"
          >
            <HelpCircle className="w-3.5 h-3.5" />
            <span>Need Help</span>
          </button>
          <button
            onClick={handlePrintInvoice}
            className="px-3.5 py-2 text-xs font-semibold text-white bg-zinc-900 hover:bg-zinc-800 rounded-lg flex items-center gap-1.5 transition-colors cursor-pointer"
          >
            <Printer className="w-3.5 h-3.5" />
            <span>Print Tax Invoice</span>
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 mt-8">
        {/* Left Column: Live Progress & Interactive Map */}
        <div className="lg:col-span-8 space-y-6">
          {/* Status Tracker Bar */}
          <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
            <div className="flex items-center justify-between mb-8">
              <div>
                <div className="text-xs text-zinc-400">Estimated Delivery:</div>
                <div className="text-lg font-bold text-emerald-800 font-display">
                  {activeOrder.status === 'delivered'
                    ? 'Delivered Successfully!'
                    : activeOrder.estimatedDeliveryTime}
                </div>
              </div>
              <div className="text-right">
                <div className="text-xs text-zinc-400">Payment Status:</div>
                <div className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                  {activeOrder.paymentMethod.toUpperCase()} · {activeOrder.paymentStatus}
                </div>
              </div>
            </div>

            {/* Step Progress Line */}
            <div className="relative">
              <div className="hidden sm:block absolute top-1/2 left-0 right-0 h-1 bg-zinc-100 -translate-y-1/2 z-0" />
              <div
                className="hidden sm:block absolute top-1/2 left-0 h-1 bg-emerald-600 -translate-y-1/2 z-0 transition-all duration-500"
                style={{ width: `${(currentStepIndex / 4) * 100}%` }}
              />

              <div className="grid grid-cols-1 sm:grid-cols-5 gap-4 relative z-10">
                {steps.map((st, idx) => {
                  const isDone = idx <= currentStepIndex;
                  const isCurrent = idx === currentStepIndex;
                  return (
                    <div
                      key={st.key}
                      className="flex sm:flex-col items-center sm:text-center gap-3 sm:gap-2"
                    >
                      <div
                        className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs transition-colors shrink-0 ${
                          isDone
                            ? 'bg-emerald-600 text-white ring-4 ring-emerald-50'
                            : 'bg-zinc-100 text-zinc-400 border border-zinc-200'
                        }`}
                      >
                        {isDone ? <CheckCircle2 className="w-5 h-5" /> : idx + 1}
                      </div>

                      <div>
                        <div
                          className={`text-xs font-semibold ${
                            isCurrent ? 'text-emerald-900 font-bold' : isDone ? 'text-zinc-800' : 'text-zinc-400'
                          }`}
                        >
                          {st.label}
                        </div>
                        <div className="text-[10px] text-zinc-400 hidden sm:block mt-0.5">
                          {st.desc}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Interactive Simulated Live Delivery Map */}
          <div className="bg-zinc-900 rounded-2xl overflow-hidden border border-zinc-800 p-6 relative">
            <div className="flex items-center justify-between text-xs text-zinc-300 pb-4 border-b border-zinc-800">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                <span className="font-semibold text-emerald-400">Live GPS Radar</span>
              </div>
              <span>Kathmandu Valley Cold-Chain Route</span>
            </div>

            {/* Map Canvas Graphic */}
            <div className="h-64 my-4 relative rounded-xl bg-zinc-950 overflow-hidden flex items-center justify-center border border-zinc-800">
              {/* Street grid pattern simulation */}
              <div
                className="absolute inset-0 opacity-20"
                style={{
                  backgroundImage:
                    'radial-gradient(#34d399 1px, transparent 1px), radial-gradient(#71717a 1px, transparent 1px)',
                  backgroundSize: '24px 24px',
                }}
              />

              {/* Hub Marker */}
              <div className="absolute top-12 left-12 flex flex-col items-center">
                <div className="w-8 h-8 rounded-full bg-emerald-700/80 text-white flex items-center justify-center text-xs font-bold shadow-lg">
                  HUB
                </div>
                <span className="text-[10px] text-zinc-400 mt-1 font-mono">Lalitpur Hub</span>
              </div>

              {/* Route connecting line */}
              <div className="absolute top-16 left-16 right-20 bottom-16 border-t-2 border-r-2 border-dashed border-emerald-500/50 pointer-events-none rounded-tr-3xl" />

              {/* Delivery Rider on Route */}
              <div
                className="absolute flex flex-col items-center transition-all duration-1000"
                style={{
                  top: activeOrder.status === 'delivered' ? '70%' : activeOrder.status === 'out_for_delivery' ? '40%' : '20%',
                  left: activeOrder.status === 'delivered' ? '80%' : activeOrder.status === 'out_for_delivery' ? '50%' : '20%',
                }}
              >
                <div className="p-2 bg-emerald-500 text-zinc-950 rounded-full shadow-xl animate-bounce">
                  <Truck className="w-5 h-5" />
                </div>
                <span className="text-[10px] bg-zinc-900/90 text-emerald-300 px-2 py-0.5 rounded mt-1 font-mono">
                  {activeOrder.deliveryPersonName || 'Express Rider'}
                </span>
              </div>

              {/* Customer Destination Marker */}
              <div className="absolute bottom-10 right-12 flex flex-col items-center">
                <div className="w-8 h-8 rounded-full bg-rose-600/80 text-white flex items-center justify-center text-xs font-bold shadow-lg">
                  <MapPin className="w-4 h-4" />
                </div>
                <span className="text-[10px] text-zinc-300 mt-1 font-mono">
                  {activeOrder.deliveryAddress.street.slice(0, 16)}...
                </span>
              </div>
            </div>

            {/* Rider Details Card */}
            {activeOrder.deliveryPersonName && (
              <div className="bg-zinc-800/80 rounded-xl p-4 flex items-center justify-between gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-emerald-700 text-white font-bold flex items-center justify-center text-sm">
                    {activeOrder.deliveryPersonName.slice(0, 1)}
                  </div>
                  <div>
                    <h4 className="text-xs font-semibold text-zinc-100">
                      {activeOrder.deliveryPersonName}
                    </h4>
                    <div className="text-[11px] text-zinc-400">
                      Eco Electric Rider · 4.9★ (1,240 deliveries)
                    </div>
                  </div>
                </div>

                <a
                  href={`tel:${activeOrder.deliveryPersonPhone || '+9779813009988'}`}
                  className="px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors"
                >
                  <Phone className="w-3.5 h-3.5" />
                  <span>Call Rider</span>
                </a>
              </div>
            )}
          </div>

          {/* Detailed Timeline Events */}
          <div className="bg-white rounded-2xl border border-zinc-200 p-6">
            <h3 className="font-semibold text-sm text-zinc-900 mb-4">Milestone Activity Log</h3>
            <div className="space-y-4">
              {activeOrder.timeline.map((item, idx) => (
                <div key={idx} className="flex items-start gap-3 text-xs">
                  <div className="w-2 h-2 rounded-full bg-emerald-600 mt-1.5 shrink-0" />
                  <div className="flex-1">
                    <div className="flex items-center justify-between">
                      <span className="font-bold text-zinc-900">{item.title}</span>
                      <span className="text-[11px] text-zinc-400 tabular-nums">{item.timestamp}</span>
                    </div>
                    <p className="text-zinc-600 mt-0.5">{item.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right Column: Receipt Breakdown & Delivery Destination */}
        <div className="lg:col-span-4 space-y-6">
          {/* Destination Details */}
          <div className="bg-white rounded-2xl border border-zinc-200/90 p-5 shadow-2xs text-xs">
            <h3 className="font-semibold text-xs uppercase tracking-wider text-zinc-800 pb-3 border-b border-zinc-100 flex items-center gap-1.5">
              <MapPin className="w-3.5 h-3.5 text-emerald-700" />
              <span>Delivery Address</span>
            </h3>
            <div className="mt-3 space-y-1">
              <div className="font-bold text-zinc-900">{activeOrder.deliveryAddress.fullName}</div>
              <div className="text-zinc-600">{activeOrder.deliveryAddress.phone}</div>
              <div className="text-zinc-700 mt-1">{activeOrder.deliveryAddress.street}</div>
              <div className="text-zinc-500">
                {activeOrder.deliveryAddress.city}, {activeOrder.deliveryAddress.province}
              </div>
              {activeOrder.deliveryAddress.deliveryInstructions && (
                <div className="mt-2 p-2 bg-zinc-50 rounded text-zinc-500 italic">
                  Note: {activeOrder.deliveryAddress.deliveryInstructions}
                </div>
              )}
            </div>
          </div>

          {/* Itemized Receipt */}
          <div className="bg-white rounded-2xl border border-zinc-200/90 p-5 shadow-2xs">
            <h3 className="font-semibold text-xs uppercase tracking-wider text-zinc-800 pb-3 border-b border-zinc-100 flex items-center justify-between">
              <span>BASKET ITEMS ({activeOrder.items.length})</span>
              <button
                onClick={handleReorder}
                className="text-emerald-700 hover:text-emerald-900 font-semibold normal-case text-xs flex items-center gap-1 cursor-pointer"
              >
                <RotateCcw className="w-3 h-3" />
                <span>Reorder All</span>
              </button>
            </h3>

            <div className="divide-y divide-zinc-100 my-3 max-h-60 overflow-y-auto pr-1">
              {activeOrder.items.map((it) => (
                <div key={it.productId} className="py-2.5 flex items-center justify-between text-xs">
                  <div>
                    <div className="font-medium text-zinc-900 line-clamp-1">{it.product.name}</div>
                    <div className="text-[11px] text-zinc-400">
                      {it.quantity} × {it.unit}
                    </div>
                  </div>
                  <div className="font-semibold text-zinc-900 tabular-nums font-mono">
                    {formatPrice(it.product.price * it.quantity)}
                  </div>
                </div>
              ))}
            </div>

            {/* Financials */}
            <div className="pt-3 border-t border-zinc-100 space-y-1.5 text-xs text-zinc-600">
              <div className="flex justify-between">
                <span>Subtotal</span>
                <span className="font-semibold text-zinc-900 tabular-nums font-mono">
                  {formatPrice(activeOrder.subtotal)}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Delivery</span>
                <span className="tabular-nums font-mono">
                  {activeOrder.deliveryFee === 0 ? 'FREE' : formatPrice(activeOrder.deliveryFee)}
                </span>
              </div>
              {activeOrder.discount > 0 && (
                <div className="flex justify-between text-emerald-700 font-medium">
                  <span>Discount</span>
                  <span className="tabular-nums font-mono">
                    -{formatPrice(activeOrder.discount)}
                  </span>
                </div>
              )}
              {activeOrder.tip > 0 && (
                <div className="flex justify-between">
                  <span>Rider Tip</span>
                  <span className="tabular-nums font-mono">
                    {formatPrice(activeOrder.tip)}
                  </span>
                </div>
              )}
              <div className="pt-2 border-t border-zinc-200 flex justify-between items-baseline font-bold text-sm text-zinc-950">
                <span>Total Amount</span>
                <span className="text-base text-emerald-900 tabular-nums font-mono">
                  {formatPrice(activeOrder.total)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Support Modal */}
      {showSupportModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-xs">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 text-center border border-zinc-200">
            <ShieldCheck className="w-10 h-10 mx-auto text-amber-600 mb-2" />
            <h3 className="font-bold text-base text-zinc-900">Ram Prasad Store Support</h3>
            <p className="text-xs text-zinc-500 mt-1">
              Need to alter instructions or report an issue with order #{activeOrder.orderNumber}?
            </p>

            <div className="my-4 p-3 bg-zinc-50 rounded-xl text-left text-xs space-y-1">
              <div><strong>Store Counter:</strong> 01-5912345 / 9841234567</div>
              <div><strong>Email:</strong> help@ramprasadstore.com.np</div>
              <div><strong>WhatsApp:</strong> +977 9841234567</div>
            </div>

            <button
              onClick={() => setShowSupportModal(false)}
              className="w-full py-2 bg-zinc-900 text-white rounded-lg text-xs font-semibold cursor-pointer"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
