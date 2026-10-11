import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { ProductCard } from './ProductCard';
import {
  Package,
  MapPin,
  Heart,
  Bell,
  User,
  Trash2,
  Check,
  Plus,
  ArrowRight,
  RotateCcw,
} from 'lucide-react';

export const UserAccountView: React.FC = () => {
  const {
    orders,
    addresses,
    addAddress,
    deleteAddress,
    setDefaultAddress,
    wishlist,
    products,
    notifications,
    markNotificationRead,
    clearNotifications,
    setActiveOrderId,
    setActivePage,
    formatPrice,
    addToCart,
    cancelOrder,
  } = useStore();

  const [activeTab, setActiveTab] = useState<
    'orders' | 'addresses' | 'wishlist' | 'notifications' | 'profile'
  >('orders');

  // New address state
  const [showAddAddr, setShowAddAddr] = useState(false);
  const [title, setTitle] = useState<'Home' | 'Work' | 'Other'>('Home');
  const [fullName, setFullName] = useState('Guest Customer');
  const [phone, setPhone] = useState('+977 9841234567');
  const [street, setStreet] = useState('');
  const [city, setCity] = useState('Kathmandu');
  const [instructions, setInstructions] = useState('');

  // Wishlist products
  const wishlistedProducts = products.filter((p) => wishlist.includes(p.id));

  const handleCreateAddress = (e: React.FormEvent) => {
    e.preventDefault();
    if (!street.trim()) return;
    addAddress({
      title,
      fullName,
      phone,
      street,
      city,
      province: 'Bagmati Province',
      postalCode: '44600',
      isDefault: false,
      deliveryInstructions: instructions,
    });
    setStreet('');
    setInstructions('');
    setShowAddAddr(false);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Profile Header */}
      <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-2xs">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-emerald-700 text-white font-bold text-xl flex items-center justify-center shadow-xs">
            SS
          </div>
          <div>
            <h1 className="text-xl font-display font-bold text-zinc-950">Guest Customer</h1>
            <div className="text-xs text-zinc-500 mt-0.5">
              customer@example.com · +977 9800000000
            </div>
            <div className="text-[11px] text-amber-800 font-bold mt-1">
              Ram Prasad Store Patron Member · Jhamsikhel, Lalitpur
            </div>
          </div>
        </div>

        <div className="flex items-center gap-6 text-xs text-zinc-600 border-t sm:border-t-0 pt-3 sm:pt-0 border-zinc-100 w-full sm:w-auto">
          <div>
            <div className="font-bold text-zinc-900 text-base tabular-nums font-mono">
              {orders.length}
            </div>
            <div className="text-zinc-400">Total Orders</div>
          </div>
          <div className="border-l border-zinc-200 pl-6">
            <div className="font-bold text-zinc-900 text-base tabular-nums font-mono">
              {wishlist.length}
            </div>
            <div className="text-zinc-400">Saved Items</div>
          </div>
        </div>
      </div>

      {/* Navigation Tabs (Adhering to Segmented Control design) */}
      <div className="flex items-center gap-1 p-1 bg-zinc-100 rounded-xl my-6 max-w-xl overflow-x-auto">
        <button
          onClick={() => setActiveTab('orders')}
          className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
            activeTab === 'orders'
              ? 'bg-white text-zinc-950 shadow-xs'
              : 'text-zinc-600 hover:text-zinc-900'
          }`}
        >
          <Package className="w-3.5 h-3.5" />
          <span>Orders ({orders.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('addresses')}
          className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
            activeTab === 'addresses'
              ? 'bg-white text-zinc-950 shadow-xs'
              : 'text-zinc-600 hover:text-zinc-900'
          }`}
        >
          <MapPin className="w-3.5 h-3.5" />
          <span>Addresses ({addresses.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('wishlist')}
          className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
            activeTab === 'wishlist'
              ? 'bg-white text-zinc-950 shadow-xs'
              : 'text-zinc-600 hover:text-zinc-900'
          }`}
        >
          <Heart className="w-3.5 h-3.5" />
          <span>Wishlist ({wishlist.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('notifications')}
          className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
            activeTab === 'notifications'
              ? 'bg-white text-zinc-950 shadow-xs'
              : 'text-zinc-600 hover:text-zinc-900'
          }`}
        >
          <Bell className="w-3.5 h-3.5" />
          <span>Alerts ({notifications.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('profile')}
          className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
            activeTab === 'profile'
              ? 'bg-white text-zinc-950 shadow-xs'
              : 'text-zinc-600 hover:text-zinc-900'
          }`}
        >
          <User className="w-3.5 h-3.5" />
          <span>Profile</span>
        </button>
      </div>

      {/* TAB CONTENT: ORDERS */}
      {activeTab === 'orders' && (
        <div className="space-y-4">
          {orders.length === 0 ? (
            <div className="bg-white rounded-2xl border border-zinc-200 p-12 text-center">
              <Package className="w-10 h-10 mx-auto text-zinc-300 mb-2" />
              <h3 className="font-semibold text-zinc-800 text-sm">No grocery orders yet</h3>
              <p className="text-xs text-zinc-500 mt-1">Start your fresh organic harvest basket now.</p>
              <button
                onClick={() => setActivePage('market')}
                className="mt-4 px-4 py-2 bg-emerald-700 text-white rounded-lg text-xs font-semibold"
              >
                Go to Catalog
              </button>
            </div>
          ) : (
            orders.map((ord) => (
              <div
                key={ord.id}
                className="bg-white rounded-2xl border border-zinc-200/90 p-5 shadow-2xs hover:border-zinc-300 transition-all"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-zinc-100">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-sm text-zinc-950">
                        Order #{ord.orderNumber}
                      </span>
                      <span className="text-xs text-zinc-400">
                        · {new Date(ord.createdAt).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="text-xs text-zinc-500 mt-0.5">
                      Delivery to {ord.deliveryAddress.fullName} · {ord.deliveryAddress.street}
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    <span
                      className={`text-xs font-bold uppercase tracking-wider px-2.5 py-0.5 rounded ${
                        ord.status === 'delivered'
                          ? 'bg-emerald-50 text-emerald-800 border border-emerald-200'
                          : ord.status === 'out_for_delivery'
                          ? 'bg-purple-50 text-[#5C2D91] border border-purple-200 animate-pulse'
                          : ord.status === 'cancelled'
                          ? 'bg-rose-50 text-rose-800 border border-rose-200'
                          : 'bg-amber-50 text-amber-800 border border-amber-200'
                      }`}
                    >
                      {ord.status.replace('_', ' ')}
                    </span>

                    <button
                      onClick={() => {
                        setActiveOrderId(ord.id);
                        setActivePage('tracking');
                      }}
                      className="px-3 py-1.5 bg-zinc-900 hover:bg-zinc-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1 cursor-pointer"
                    >
                      <span>Track Live</span>
                      <ArrowRight className="w-3 h-3" />
                    </button>
                  </div>
                </div>

                {/* Items preview */}
                <div className="py-3 flex flex-wrap items-center justify-between gap-4">
                  <div className="flex items-center gap-2 overflow-x-auto py-1">
                    {ord.items.map((it) => (
                      <div
                        key={it.productId}
                        className="flex items-center gap-2 bg-zinc-50 px-2.5 py-1.5 rounded-lg border border-zinc-200 text-xs shrink-0"
                      >
                        <img
                          src={it.product.image}
                          alt={it.product.name}
                          className="w-6 h-6 rounded object-cover"
                        />
                        <span className="font-medium text-zinc-800 truncate max-w-[140px]">
                          {it.product.name}
                        </span>
                        <span className="text-zinc-400">×{it.quantity}</span>
                      </div>
                    ))}
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="text-right">
                      <div className="text-xs text-zinc-400">Total Paid</div>
                      <div className="font-bold text-sm text-zinc-950 tabular-nums font-mono">
                        {formatPrice(ord.total)}
                      </div>
                    </div>

                    {ord.status === 'placed' && (
                      <button
                        onClick={() => {
                          if (window.confirm('Cancel this pending order?')) {
                            cancelOrder(ord.id);
                          }
                        }}
                        className="text-xs text-rose-600 hover:underline cursor-pointer"
                      >
                        Cancel
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* TAB CONTENT: SAVED ADDRESSES */}
      {activeTab === 'addresses' && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-sm text-zinc-900">Your Delivery Addresses</h3>
            <button
              onClick={() => setShowAddAddr(!showAddAddr)}
              className="px-3.5 py-1.5 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg text-xs font-semibold flex items-center gap-1 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add New Address</span>
            </button>
          </div>

          {showAddAddr && (
            <form onSubmit={handleCreateAddress} className="bg-white p-5 rounded-2xl border border-zinc-200 mb-6 space-y-3">
              <h4 className="font-bold text-xs uppercase tracking-wider text-zinc-800">Add New Address</h4>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Tag</label>
                  <select
                    value={title}
                    onChange={(e) => setTitle(e.target.value as any)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
                  >
                    <option value="Home">Home</option>
                    <option value="Work">Work</option>
                    <option value="Other">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Full Name</label>
                  <input
                    type="text"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Phone</label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Street / House / Landmark</label>
                <input
                  type="text"
                  placeholder="e.g. Ward 3, Jhamsikhel near British School"
                  value={street}
                  onChange={(e) => setStreet(e.target.value)}
                  className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">City</label>
                  <input
                    type="text"
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Instructions</label>
                  <input
                    type="text"
                    placeholder="e.g. Leave with guard"
                    value={instructions}
                    onChange={(e) => setInstructions(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddAddr(false)}
                  className="px-3 py-1.5 text-xs text-zinc-600 bg-zinc-100 rounded-lg"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 text-xs font-semibold text-white bg-emerald-700 rounded-lg"
                >
                  Save Address
                </button>
              </div>
            </form>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {addresses.map((addr) => (
              <div
                key={addr.id}
                className="bg-white rounded-2xl border border-zinc-200 p-5 shadow-2xs flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-sm text-zinc-900">{addr.title}</span>
                    {addr.isDefault && (
                      <span className="text-[10px] font-semibold text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded">
                        Default
                      </span>
                    )}
                  </div>
                  <div className="text-xs text-zinc-700 mt-2 font-medium">{addr.fullName} · {addr.phone}</div>
                  <p className="text-xs text-zinc-500 mt-1">{addr.street}, {addr.city}</p>
                  {addr.deliveryInstructions && (
                    <div className="text-[11px] text-zinc-400 italic mt-2">
                      Note: {addr.deliveryInstructions}
                    </div>
                  )}
                </div>

                <div className="pt-4 mt-4 border-t border-zinc-100 flex items-center justify-between text-xs">
                  {!addr.isDefault ? (
                    <button
                      onClick={() => setDefaultAddress(addr.id)}
                      className="text-emerald-700 hover:underline font-medium cursor-pointer"
                    >
                      Set as Default
                    </button>
                  ) : (
                    <span className="text-zinc-400">Current Default</span>
                  )}

                  {addresses.length > 1 && (
                    <button
                      onClick={() => deleteAddress(addr.id)}
                      className="text-zinc-400 hover:text-rose-600 transition-colors cursor-pointer"
                      title="Delete address"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB CONTENT: WISHLIST */}
      {activeTab === 'wishlist' && (
        <div>
          {wishlistedProducts.length === 0 ? (
            <div className="bg-white rounded-2xl border border-zinc-200 p-12 text-center">
              <Heart className="w-10 h-10 mx-auto text-zinc-300 mb-2" />
              <h3 className="font-semibold text-zinc-800 text-sm">Your wishlist is empty</h3>
              <p className="text-xs text-zinc-500 mt-1">Tap the heart on any product to save it here.</p>
              <button
                onClick={() => setActivePage('market')}
                className="mt-4 px-4 py-2 bg-emerald-700 text-white rounded-lg text-xs font-semibold"
              >
                Browse Catalog
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
              {wishlistedProducts.map((prod) => (
                <ProductCard key={prod.id} product={prod} />
              ))}
            </div>
          )}
        </div>
      )}

      {/* TAB CONTENT: NOTIFICATIONS */}
      {activeTab === 'notifications' && (
        <div className="bg-white rounded-2xl border border-zinc-200 p-6">
          <div className="flex items-center justify-between pb-4 border-b border-zinc-100 mb-4">
            <h3 className="font-semibold text-sm text-zinc-900">Notifications & Delivery Updates</h3>
            <button
              onClick={clearNotifications}
              className="text-xs text-zinc-500 hover:text-zinc-800"
            >
              Clear all
            </button>
          </div>

          <div className="divide-y divide-zinc-100 space-y-1">
            {notifications.map((notif) => (
              <div
                key={notif.id}
                onClick={() => markNotificationRead(notif.id)}
                className={`p-3 rounded-xl transition-colors cursor-pointer ${
                  notif.read ? 'opacity-70' : 'bg-emerald-50/50'
                }`}
              >
                <div className="flex items-center justify-between text-xs">
                  <span className="font-semibold text-zinc-900">{notif.title}</span>
                  <span className="text-[10px] text-zinc-400">{notif.timestamp}</span>
                </div>
                <p className="text-xs text-zinc-600 mt-1">{notif.message}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB CONTENT: PROFILE */}
      {activeTab === 'profile' && (
        <div className="bg-white rounded-2xl border border-zinc-200 p-6 max-w-xl">
          <h3 className="font-semibold text-sm text-zinc-900 mb-4">Account Profile Information</h3>
          <div className="space-y-4 text-xs">
            <div>
              <label className="block text-zinc-500 mb-1">Full Legal Name</label>
              <input
                type="text"
                defaultValue="Guest Customer"
                className="w-full p-2.5 rounded-lg border border-zinc-300 font-medium"
              />
            </div>
            <div>
              <label className="block text-zinc-500 mb-1">Email Address</label>
              <input
                type="email"
                defaultValue="customer@example.com"
                disabled
                className="w-full p-2.5 rounded-lg border border-zinc-200 bg-zinc-50 text-zinc-500 font-medium"
              />
            </div>
            <div>
              <label className="block text-zinc-500 mb-1">Registered Phone</label>
              <input
                type="tel"
                defaultValue="+977 9841234567"
                className="w-full p-2.5 rounded-lg border border-zinc-300 font-medium"
              />
            </div>
            <div>
              <label className="block text-zinc-500 mb-1">Preferred Delivery Language</label>
              <select className="w-full p-2.5 rounded-lg border border-zinc-300 bg-white">
                <option>English / Nepali</option>
                <option>Nepali Only</option>
                <option>English Only</option>
              </select>
            </div>
            <button
              type="button"
              onClick={() => alert('Profile preferences saved successfully.')}
              className="mt-2 px-5 py-2.5 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg font-semibold cursor-pointer"
            >
              Save Profile Changes
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
