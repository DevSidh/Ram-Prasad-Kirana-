import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { Address, DeliveryTimeSlot } from '../../types';
import { INITIAL_TIME_SLOTS } from '../../data/initialData';
import {
  MapPin,
  Clock,
  Tag,
  Check,
  Plus,
  ArrowLeft,
  Truck,
  HeartHandshake,
  AlertCircle,
} from 'lucide-react';

export const CheckoutView: React.FC = () => {
  const {
    cart,
    cartSubtotal,
    formatPrice,
    addresses,
    addAddress,
    coupons,
    createOrder,
    setActivePage,
  } = useStore();

  const [selectedAddressId, setSelectedAddressId] = useState<string>(
    addresses[0]?.id || ''
  );
  const [isAddingNewAddress, setIsAddingNewAddress] = useState(false);
  const [newStreet, setNewStreet] = useState('');
  const [newCity, setNewCity] = useState('Kathmandu');
  const [newPhone, setNewPhone] = useState('+977 9841234567');
  const [newFullName, setNewFullName] = useState('Siddhant Shah');
  const [newInstructions, setNewInstructions] = useState('');

  const [selectedSlotId, setSelectedSlotId] = useState<string>('slot-express');
  const [couponCodeInput, setCouponCodeInput] = useState('');
  const [appliedCoupon, setAppliedCoupon] = useState<string | null>('RAMPRASAD10');
  const [couponError, setCouponError] = useState<string | null>(null);
  const [tip, setTip] = useState<number>(40);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (cart.length === 0) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <h2 className="text-xl font-bold text-zinc-900">Your shopping bag is empty</h2>
        <p className="text-xs text-zinc-500 mt-1">Please add everyday items from Ram Prasad General Store before checkout.</p>
        <button
          onClick={() => setActivePage('market')}
          className="mt-4 px-5 py-2.5 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-bold cursor-pointer"
        >
          Return to Store Catalog
        </button>
      </div>
    );
  }

  // Address selection
  const selectedAddress =
    addresses.find((a) => a.id === selectedAddressId) || addresses[0];

  // Slot selection
  const selectedSlot =
    INITIAL_TIME_SLOTS.find((s) => s.id === selectedSlotId) || INITIAL_TIME_SLOTS[0];

  // Delivery fee: if order >= 1000 and slot isn't express, delivery is free.
  const deliveryFee =
    cartSubtotal >= 1000 && selectedSlot.id !== 'slot-express'
      ? 0
      : selectedSlot.fee;

  // Calculate discount
  let discountAmount = 0;
  if (appliedCoupon) {
    const couponObj = coupons.find((c) => c.code === appliedCoupon && c.active);
    if (couponObj) {
      if (cartSubtotal >= couponObj.minOrderAmount) {
        discountAmount = Math.min(
          couponObj.maxDiscount,
          (cartSubtotal * couponObj.discountPercent) / 100
        );
      }
    }
  }

  const grandTotal = Math.max(0, cartSubtotal + deliveryFee - discountAmount + tip);

  const handleApplyCoupon = (e: React.FormEvent) => {
    e.preventDefault();
    setCouponError(null);
    const code = couponCodeInput.trim().toUpperCase();
    const found = coupons.find((c) => c.code === code && c.active);
    if (!found) {
      setCouponError('Invalid or expired coupon code. Try FRESH20');
      return;
    }
    if (cartSubtotal < found.minOrderAmount) {
      setCouponError(`Requires minimum order of ${formatPrice(found.minOrderAmount)}`);
      return;
    }
    setAppliedCoupon(found.code);
    setCouponCodeInput('');
  };

  const handleSaveNewAddress = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newStreet.trim()) return;
    addAddress({
      title: 'Home',
      fullName: newFullName,
      phone: newPhone,
      street: newStreet,
      city: newCity,
      province: 'Bagmati Province',
      postalCode: '44600',
      isDefault: false,
      deliveryInstructions: newInstructions,
    });
    setIsAddingNewAddress(false);
  };

  const finalizeOrder = () => {
    setIsSubmitting(true);
    setTimeout(() => {
      createOrder({
        address: selectedAddress,
        timeSlot: selectedSlot,
        paymentMethod: 'cod',
        couponCode: appliedCoupon || undefined,
        discount: discountAmount,
        deliveryFee,
        tip,
      });
      setIsSubmitting(false);
      setActivePage('tracking');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }, 600);
  };

  const handlePlaceOrderClick = () => {
    if (!selectedAddress) {
      alert('Please select or add a delivery address.');
      return;
    }

    finalizeOrder();
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Back button */}
      <div className="mb-6">
        <button
          onClick={() => setActivePage('market')}
          className="text-xs font-semibold text-zinc-500 hover:text-zinc-900 flex items-center gap-1.5 transition-colors cursor-pointer"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Back to Shopping</span>
        </button>
        <h1 className="text-2xl sm:text-3xl font-display font-bold text-zinc-950 mt-2">
          Express Checkout
        </h1>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Left Form: Steps */}
        <div className="lg:col-span-8 space-y-8">
          {/* STEP 1: Delivery Address */}
          <section className="bg-white rounded-2xl border border-zinc-200/90 p-5 sm:p-6 shadow-2xs">
            <div className="flex items-center justify-between pb-4 border-b border-zinc-100">
              <div className="flex items-center gap-2.5">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-xs">
                  1
                </div>
                <h2 className="font-semibold text-base text-zinc-900">
                  Delivery Destination
                </h2>
              </div>
              <button
                type="button"
                onClick={() => setIsAddingNewAddress(!isAddingNewAddress)}
                className="text-xs text-emerald-800 font-semibold hover:underline flex items-center gap-1 cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>{isAddingNewAddress ? 'Cancel' : 'Add New Address'}</span>
              </button>
            </div>

            {/* Saved Addresses Picker */}
            {!isAddingNewAddress ? (
              <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
                {addresses.map((addr) => {
                  const isSelected = selectedAddressId === addr.id;
                  return (
                    <div
                      key={addr.id}
                      onClick={() => setSelectedAddressId(addr.id)}
                      className={`p-3.5 rounded-xl border text-xs cursor-pointer transition-all ${
                        isSelected
                          ? 'border-emerald-700 bg-emerald-50/50 ring-2 ring-emerald-700/20'
                          : 'border-zinc-200 hover:border-zinc-300 bg-zinc-50/30'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-zinc-900">{addr.title}</span>
                        {isSelected && <Check className="w-4 h-4 text-emerald-700" />}
                      </div>
                      <div className="text-zinc-700 font-medium mt-1">{addr.fullName} · {addr.phone}</div>
                      <p className="text-zinc-500 mt-1 line-clamp-2">{addr.street}, {addr.city}</p>
                      {addr.deliveryInstructions && (
                        <div className="mt-2 text-[11px] text-zinc-400 italic">
                          Note: {addr.deliveryInstructions}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            ) : (
              /* Add New Address Form */
              <form onSubmit={handleSaveNewAddress} className="mt-4 space-y-3 bg-zinc-50 p-4 rounded-xl border border-zinc-200">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-zinc-700 mb-1">Full Name</label>
                    <input
                      type="text"
                      value={newFullName}
                      onChange={(e) => setNewFullName(e.target.value)}
                      className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-zinc-700 mb-1">Phone Number</label>
                    <input
                      type="tel"
                      value={newPhone}
                      onChange={(e) => setNewPhone(e.target.value)}
                      className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Street / House / Landmark</label>
                  <input
                    type="text"
                    placeholder="e.g. Ward 4, Baluwatar near Russian Embassy"
                    value={newStreet}
                    onChange={(e) => setNewStreet(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                    required
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-zinc-700 mb-1">City</label>
                    <input
                      type="text"
                      value={newCity}
                      onChange={(e) => setNewCity(e.target.value)}
                      className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-zinc-700 mb-1">Delivery Instructions</label>
                    <input
                      type="text"
                      placeholder="e.g. Ring left bell"
                      value={newInstructions}
                      onChange={(e) => setNewInstructions(e.target.value)}
                      className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                    />
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <button
                    type="button"
                    onClick={() => setIsAddingNewAddress(false)}
                    className="px-3 py-1.5 text-xs text-zinc-600 bg-zinc-200 rounded-lg"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-1.5 text-xs text-white bg-emerald-700 rounded-lg font-semibold"
                  >
                    Save Address
                  </button>
                </div>
              </form>
            )}
          </section>

          {/* STEP 2: Delivery Time Slot */}
          <section className="bg-white rounded-2xl border border-zinc-200/90 p-5 sm:p-6 shadow-2xs">
            <div className="flex items-center gap-2.5 pb-4 border-b border-zinc-100">
              <div className="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-xs">
                2
              </div>
              <h2 className="font-semibold text-base text-zinc-900">
                Delivery Schedule & Speed
              </h2>
            </div>

            <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
              {INITIAL_TIME_SLOTS.map((slot) => {
                const isSelected = selectedSlotId === slot.id;
                return (
                  <div
                    key={slot.id}
                    onClick={() => setSelectedSlotId(slot.id)}
                    className={`p-3.5 rounded-xl border text-xs cursor-pointer transition-all flex items-center justify-between ${
                      isSelected
                        ? 'border-emerald-700 bg-emerald-50/50 ring-2 ring-emerald-700/20'
                        : 'border-zinc-200 hover:border-zinc-300'
                    }`}
                  >
                    <div>
                      <div className="font-bold text-zinc-900 flex items-center gap-1.5">
                        <Clock className="w-3.5 h-3.5 text-emerald-700" />
                        <span>{slot.label}</span>
                      </div>
                      <div className="text-zinc-500 mt-1">{slot.date} · {slot.timeWindow}</div>
                    </div>
                    <div className="text-right">
                      <span className="font-semibold text-zinc-900 tabular-nums font-mono">
                        {slot.fee === 0 ? 'FREE' : formatPrice(slot.fee)}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>

          {/* STEP 3: Payment Method Abstraction */}
          <section className="bg-white rounded-2xl border border-zinc-200/90 p-5 sm:p-6 shadow-2xs">
            <div className="flex items-center gap-2.5 pb-4 border-b border-zinc-100">
              <div className="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-xs">
                3
              </div>
              <h2 className="font-semibold text-base text-zinc-900">
                Payment Method
              </h2>
            </div>

            <div className="mt-4">
              {/* Cash on Delivery */}
              <div
                className="p-4 rounded-xl border border-emerald-700 bg-emerald-50/50 ring-2 ring-emerald-700/20 text-xs"
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="font-bold text-zinc-900">Cash on Delivery (COD)</span>
                  <Check className="w-4 h-4 text-emerald-700" />
                </div>
                <p className="text-zinc-500 text-[11px]">
                  Pay cash or Scan-to-Pay QR when your groceries arrive at your doorstep.
                </p>
              </div>
            </div>
          </section>
        </div>

        {/* Right Summary & Checkout Action */}
        <div className="lg:col-span-4 space-y-6">
          <div className="bg-white rounded-2xl border border-zinc-200/90 p-5 sm:p-6 shadow-sm sticky top-24">
            <h3 className="font-display font-bold text-base text-zinc-950 pb-4 border-b border-zinc-100">
              Order Breakdown
            </h3>

            {/* Itemized Snapshot */}
            <div className="max-h-56 overflow-y-auto divide-y divide-zinc-100 my-4 pr-1">
              {cart.map((item) => {
                const itemKey = item.selectedVariant ? `${item.productId}__${item.selectedVariant}` : item.productId;
                const unitPrice = item.variantPrice !== undefined ? item.variantPrice : item.product.price;
                return (
                  <div key={itemKey} className="py-2.5 flex items-center justify-between text-xs">
                    <div className="flex-1 pr-2 truncate">
                      <span className="font-medium text-zinc-800">{item.product.name}</span>
                      {item.selectedVariant && (
                        <span className="ml-1.5 text-[10px] text-amber-800 font-bold bg-amber-50 px-1 py-0.2 rounded">
                          {item.selectedVariant}
                        </span>
                      )}
                      <div className="text-[11px] text-zinc-400">
                        {item.quantity} × {item.unit}
                      </div>
                    </div>
                    <span className="font-semibold text-zinc-950 tabular-nums font-mono">
                      {formatPrice(unitPrice * item.quantity)}
                    </span>
                  </div>
                );
              })}
            </div>

            {/* Coupon Application Form */}
            <form onSubmit={handleApplyCoupon} className="pt-3 border-t border-zinc-100">
              <label className="block text-xs font-semibold text-zinc-700 mb-1.5 flex items-center gap-1">
                <Tag className="w-3.5 h-3.5 text-emerald-700" />
                <span>Promo Code / Voucher</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="e.g. FRESH20"
                  value={couponCodeInput}
                  onChange={(e) => setCouponCodeInput(e.target.value)}
                  className="flex-1 text-xs uppercase p-2 rounded-lg border border-zinc-300 focus:outline-emerald-600"
                />
                <button
                  type="submit"
                  className="px-3 py-2 bg-zinc-900 hover:bg-zinc-800 text-white rounded-lg text-xs font-semibold cursor-pointer"
                >
                  Apply
                </button>
              </div>

              {appliedCoupon && (
                <div className="mt-2 text-xs text-emerald-800 bg-emerald-50 border border-emerald-200 p-2 rounded-lg flex items-center justify-between">
                  <span>Coupon {appliedCoupon} Applied!</span>
                  <button
                    type="button"
                    onClick={() => setAppliedCoupon(null)}
                    className="text-emerald-950 font-bold hover:underline"
                  >
                    Remove
                  </button>
                </div>
              )}

              {couponError && (
                <div className="mt-1.5 text-[11px] text-rose-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  <span>{couponError}</span>
                </div>
              )}
            </form>

            {/* Rider Tip */}
            <div className="pt-4 border-t border-zinc-100 mt-4">
              <div className="text-xs font-semibold text-zinc-700 mb-2 flex items-center gap-1">
                <HeartHandshake className="w-3.5 h-3.5 text-emerald-700" />
                <span>Tip for Delivery Partner</span>
              </div>
              <div className="flex gap-2">
                {[0, 20, 50, 100].map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setTip(t)}
                    className={`flex-1 py-1.5 text-xs rounded-lg border transition-colors ${
                      tip === t
                        ? 'border-emerald-700 bg-emerald-50 text-emerald-900 font-bold'
                        : 'border-zinc-200 text-zinc-600 hover:bg-zinc-50'
                    }`}
                  >
                    {t === 0 ? 'None' : `Rs. ${t}`}
                  </button>
                ))}
              </div>
            </div>

            {/* Cost Summary Table */}
            <div className="pt-4 border-t border-zinc-100 mt-4 space-y-2 text-xs">
              <div className="flex justify-between text-zinc-600">
                <span>Items Subtotal</span>
                <span className="font-semibold text-zinc-900 tabular-nums font-mono">
                  {formatPrice(cartSubtotal)}
                </span>
              </div>

              <div className="flex justify-between text-zinc-600">
                <span>Delivery Fee</span>
                <span className="tabular-nums font-mono">
                  {deliveryFee === 0 ? (
                    <span className="text-emerald-700 font-bold">FREE</span>
                  ) : (
                    formatPrice(deliveryFee)
                  )}
                </span>
              </div>

              {discountAmount > 0 && (
                <div className="flex justify-between text-emerald-700 font-medium">
                  <span>Voucher Discount</span>
                  <span className="tabular-nums font-mono">
                    -{formatPrice(discountAmount)}
                  </span>
                </div>
              )}

              {tip > 0 && (
                <div className="flex justify-between text-zinc-600">
                  <span>Rider Tip</span>
                  <span className="tabular-nums font-mono">
                    {formatPrice(tip)}
                  </span>
                </div>
              )}

              <div className="pt-3 border-t border-zinc-200 flex justify-between items-baseline text-base font-bold text-zinc-950">
                <span>Grand Total</span>
                <span className="text-xl text-emerald-900 tabular-nums font-mono">
                  {formatPrice(grandTotal)}
                </span>
              </div>
            </div>

            {/* Primary Submit Button */}
            <button
              type="button"
              disabled={isSubmitting}
              onClick={handlePlaceOrderClick}
              className="mt-6 w-full py-3.5 px-4 bg-emerald-700 hover:bg-emerald-800 text-white rounded-xl text-sm font-semibold flex items-center justify-center gap-2 transition-colors shadow-xs cursor-pointer disabled:opacity-50"
            >
              <Truck className="w-4 h-4" />
              <span>
                Confirm Cash On Delivery
              </span>
            </button>

            <div className="mt-3 text-center text-[11px] text-zinc-400">
              Safe & Contactless Delivery · Guaranteed Freshness
            </div>
          </div>
        </div>
      </div>

    </div>
  );
};
