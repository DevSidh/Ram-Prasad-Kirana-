import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import {
  ShoppingBag,
  Search,
  Bell,
  Heart,
  User as UserIcon,
  X,
  Check,
  Package,
} from 'lucide-react';

export const Header: React.FC = () => {
  const {
    cartCount,
    cartSubtotal,
    formatPrice,
    setIsCartDrawerOpen,
    activePage,
    setActivePage,
    searchQuery,
    setSearchQuery,
    selectedCategory,
    setSelectedCategory,
    currency,
    setCurrency,
    wishlist,
    notifications,
    unreadNotificationsCount,
    markNotificationRead,
    clearNotifications,
    setActiveOrderId,
    currentRole,
  } = useStore();

  const [isSearchExpanded, setIsSearchExpanded] = useState(false);
  const [isNotifOpen, setIsNotifOpen] = useState(false);

  const handleNavClick = (page: string, category: string = 'all') => {
    setSelectedCategory(category);
    setActivePage(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <header className="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-zinc-200 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
        {/* ZONE 1: Single text wordmark */}
        <div className="flex items-center gap-6">
          <button
            onClick={() => handleNavClick(currentRole === 'admin' ? 'admin' : currentRole === 'staff' ? 'staff' : currentRole === 'delivery' ? 'delivery' : 'home')}
            className="flex items-center gap-2.5 group text-left cursor-pointer"
          >
            <div className="w-9 h-9 rounded-lg bg-amber-600 flex items-center justify-center text-white font-black text-sm shadow-xs group-hover:bg-amber-700 transition-colors">
              RP
            </div>
            <div className="flex flex-col">
              <span className="font-display text-base sm:text-lg font-extrabold tracking-tight text-zinc-950 leading-tight">
                Ram Prasad
              </span>
              <span className="text-[10px] uppercase font-bold tracking-wider text-amber-700 leading-none">
                General Store
              </span>
            </div>
          </button>
        </div>

        {/* ZONE 2: 4-6 Clean text navigation links */}
        <nav className="hidden lg:flex items-center gap-6 text-sm font-medium text-zinc-600">
          <button
            onClick={() => handleNavClick('home')}
            className={`transition-colors hover:text-amber-700 cursor-pointer ${
              activePage === 'home' ? 'text-amber-700 font-bold' : ''
            }`}
          >
            Home
          </button>
          <button
            onClick={() => handleNavClick('market', 'all')}
            className={`transition-colors hover:text-amber-700 cursor-pointer ${
              activePage === 'market' && selectedCategory === 'all' ? 'text-amber-700 font-bold' : ''
            }`}
          >
            All Aisles
          </button>
          <button
            onClick={() => handleNavClick('market', 'food-grocery')}
            className="transition-colors hover:text-amber-700 cursor-pointer"
          >
            Food & Grocery
          </button>
          <button
            onClick={() => handleNavClick('market', 'household')}
            className="transition-colors hover:text-amber-700 cursor-pointer"
          >
            Household
          </button>
          <button
            onClick={() => handleNavClick('market', 'stationery')}
            className="transition-colors hover:text-amber-700 cursor-pointer"
          >
            Stationery
          </button>
          <button
            onClick={() => handleNavClick('market', 'electronics')}
            className="transition-colors hover:text-amber-700 cursor-pointer"
          >
            Electronics
          </button>
          <button
            onClick={() => handleNavClick('tracking')}
            className={`transition-colors hover:text-amber-700 cursor-pointer ${
              activePage === 'tracking' ? 'text-amber-700 font-bold' : ''
            }`}
          >
            Track Order
          </button>
          <button
            onClick={() => handleNavClick('mobile_simulator')}
            className={`transition-colors hover:text-amber-700 cursor-pointer flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
              activePage === 'mobile_simulator'
                ? 'bg-amber-100 text-amber-800'
                : 'bg-zinc-100 text-zinc-700 hover:bg-amber-50 hover:text-amber-800'
            }`}
          >
            <span>📱 Mobile App</span>
          </button>
        </nav>

        {/* ZONE 3: 1-2 Primary actions & utility cluster */}
        <div className="flex items-center gap-2 sm:gap-3">
          {/* Quick Search Input */}
          <div className="relative">
            {isSearchExpanded ? (
              <div className="flex items-center bg-zinc-100 rounded-lg px-2.5 py-1.5 border border-zinc-300 w-48 sm:w-64 transition-all">
                <Search className="w-4 h-4 text-zinc-400 shrink-0 mr-1.5" />
                <input
                  type="text"
                  placeholder="Search products (e.g. toothpaste, notebook, bulb, detergent)..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      setActivePage('market');
                    }
                  }}
                  autoFocus
                  className="bg-transparent text-xs w-full focus:outline-none text-zinc-900 placeholder:text-zinc-400"
                />
                <button
                  onClick={() => {
                    setIsSearchExpanded(false);
                    setSearchQuery('');
                  }}
                  className="text-zinc-400 hover:text-zinc-700"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            ) : (
              <button
                onClick={() => {
                  setIsSearchExpanded(true);
                  if (activePage !== 'market') setActivePage('market');
                }}
                className="p-2 text-zinc-600 hover:text-zinc-900 rounded-lg hover:bg-zinc-100 transition-colors"
                title="Search"
              >
                <Search className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Currency Toggle */}
          <button
            type="button"
            onClick={() => setCurrency(currency === 'NPR' ? 'USD' : 'NPR')}
            className="hidden sm:inline-flex px-2 py-1 text-xs font-semibold text-zinc-600 hover:text-zinc-950 bg-zinc-100 hover:bg-zinc-200/80 rounded-md transition-colors"
            title="Toggle Currency"
          >
            {currency === 'NPR' ? 'Rs. NPR' : '$ USD'}
          </button>

          {/* Wishlist Link */}
          <button
            onClick={() => {
              setActivePage('account');
            }}
            className="relative p-2 text-zinc-600 hover:text-zinc-900 rounded-lg hover:bg-zinc-100 transition-colors hidden sm:inline-flex"
            title="Saved Items"
          >
            <Heart className="w-4 h-4" />
            {wishlist.length > 0 && (
              <span className="absolute 1 top-1 right-1 w-2 h-2 bg-emerald-600 rounded-full" />
            )}
          </button>

          {/* Notifications Drawer */}
          <div className="relative">
            <button
              onClick={() => setIsNotifOpen(!isNotifOpen)}
              className="relative p-2 text-zinc-600 hover:text-zinc-900 rounded-lg hover:bg-zinc-100 transition-colors"
              title="Notifications"
            >
              <Bell className="w-4 h-4" />
              {unreadNotificationsCount > 0 && (
                <span className="absolute top-1 right-1 w-4 h-4 bg-emerald-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                  {unreadNotificationsCount}
                </span>
              )}
            </button>

            {isNotifOpen && (
              <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white border border-zinc-200 rounded-xl shadow-xl py-3 z-50">
                <div className="px-4 pb-2 border-b border-zinc-100 flex items-center justify-between">
                  <div className="font-semibold text-sm text-zinc-900">Notifications</div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={clearNotifications}
                      className="text-xs text-zinc-500 hover:text-zinc-800"
                    >
                      Clear all
                    </button>
                    <button onClick={() => setIsNotifOpen(false)} className="text-zinc-400 hover:text-zinc-700">
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                <div className="max-h-72 overflow-y-auto divide-y divide-zinc-100">
                  {notifications.length === 0 ? (
                    <div className="p-6 text-center text-xs text-zinc-400">No new notifications</div>
                  ) : (
                    notifications.map((notif) => (
                      <div
                        key={notif.id}
                        onClick={() => {
                          markNotificationRead(notif.id);
                          if (notif.orderId) {
                            setActiveOrderId(notif.orderId);
                            setActivePage('tracking');
                            setIsNotifOpen(false);
                          }
                        }}
                        className={`p-3 text-xs hover:bg-zinc-50 cursor-pointer transition-colors ${
                          notif.read ? 'opacity-70' : 'bg-emerald-50/40'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <span className="font-semibold text-zinc-900">{notif.title}</span>
                          <span className="text-[10px] text-zinc-400 shrink-0">{notif.timestamp}</span>
                        </div>
                        <p className="text-zinc-600 mt-1 line-clamp-2">{notif.message}</p>
                      </div>
                    ))
                  )}
                </div>
              </div>
            )}
          </div>

          {/* User Account Button */}
          <button
            onClick={() => setActivePage('account')}
            className={`p-2 text-zinc-600 hover:text-zinc-900 rounded-lg hover:bg-zinc-100 transition-colors ${
              activePage === 'account' ? 'bg-zinc-100 text-zinc-950' : ''
            }`}
            title="User Profile & Orders"
          >
            <UserIcon className="w-4 h-4" />
          </button>

          {/* Cart Trigger Button */}
          <button
            type="button"
            onClick={() => setIsCartDrawerOpen(true)}
            className="flex items-center gap-2.5 px-3.5 py-2 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg text-xs font-semibold transition-all shadow-xs cursor-pointer"
          >
            <ShoppingBag className="w-4 h-4 shrink-0" />
            <span className="tabular-nums font-mono">
              {cartCount > 0 ? `${cartCount} items` : 'Bag'}
            </span>
            {cartCount > 0 && (
              <span className="hidden sm:inline-block border-l border-emerald-600/70 pl-2 tabular-nums">
                {formatPrice(cartSubtotal)}
              </span>
            )}
          </button>
        </div>
      </div>
    </header>
  );
};
