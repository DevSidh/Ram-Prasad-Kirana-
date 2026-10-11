/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { StoreProvider, useStore } from './context/StoreContext';
import { Header } from './components/layout/Header';
import { Footer } from './components/layout/Footer';
import { HomePage } from './components/customer/HomePage';
import { MarketCatalog } from './components/customer/MarketCatalog';
import { CheckoutView } from './components/customer/CheckoutView';
import { OrderTrackingView } from './components/customer/OrderTrackingView';
import { UserAccountView } from './components/customer/UserAccountView';
import { ProductDetailModal } from './components/customer/ProductDetailModal';
import { CartDrawer } from './components/customer/CartDrawer';
import { AdminPanel } from './components/admin/AdminPanel';
import { StaffPackingView } from './components/staff/StaffPackingView';
import { DeliveryPortalView } from './components/delivery/DeliveryPortalView';
import { MobileAppViewer } from './components/mobile/MobileAppViewer';

const MainAppContent: React.FC = () => {
  const { activePage } = useStore();

  return (
    <div className="min-h-screen flex flex-col bg-[#FAFAFA] text-zinc-900 selection:bg-emerald-500 selection:text-white">
      {/* Strict 3-Zone Header Navigation */}
      <Header />

      {/* Main Page Content */}
      <main className="flex-1">
        {activePage === 'home' && <HomePage />}
        {activePage === 'market' && <MarketCatalog />}
        {activePage === 'checkout' && <CheckoutView />}
        {activePage === 'tracking' && <OrderTrackingView />}
        {activePage === 'account' && <UserAccountView />}
        {activePage === 'admin' && <AdminPanel />}
        {activePage === 'staff' && <StaffPackingView />}
        {activePage === 'delivery' && <DeliveryPortalView />}
        {activePage === 'mobile_simulator' && <MobileAppViewer />}
      </main>

      {/* Product Detail Modal */}
      <ProductDetailModal />

      {/* Slide-over Cart Drawer */}
      <CartDrawer />

      {/* Footer */}
      <Footer />
    </div>
  );
};

export default function App() {
  return (
    <StoreProvider>
      <MainAppContent />
    </StoreProvider>
  );
}
