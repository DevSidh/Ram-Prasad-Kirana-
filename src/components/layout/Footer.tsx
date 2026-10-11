import React from 'react';
import { useStore } from '../../context/StoreContext';
import { STORE_NAME } from '../../data/initialData';
import { ShieldCheck, Clock, Award, Package, ShoppingBag } from 'lucide-react';

export const Footer: React.FC = () => {
  const { setActivePage, setSelectedCategory } = useStore();

  return (
    <footer className="bg-zinc-900 text-zinc-400 text-sm border-t border-zinc-800 mt-20">
      {/* Value Proposition Highlights */}
      <div className="border-b border-zinc-800/80">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="flex items-start gap-3.5">
            <div className="p-2.5 rounded-lg bg-zinc-800 text-amber-400 shrink-0">
              <Clock className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-zinc-100 font-semibold text-sm">Express 45-Min Delivery</h4>
              <p className="text-zinc-400 text-xs mt-1 leading-relaxed">
                Neighborhood express dispatch for your daily household, grocery, and stationery emergencies.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3.5">
            <div className="p-2.5 rounded-lg bg-zinc-800 text-amber-400 shrink-0">
              <Package className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-zinc-100 font-semibold text-sm">100% Genuine Products</h4>
              <p className="text-zinc-400 text-xs mt-1 leading-relaxed">
                Directly sourced from trusted brands like Classmate, Surf Excel, Colgate, Philips, and Tata.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3.5">
            <div className="p-2.5 rounded-lg bg-zinc-800 text-amber-400 shrink-0">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-zinc-100 font-semibold text-sm">Neighborhood Trust</h4>
              <p className="text-zinc-400 text-xs mt-1 leading-relaxed">
                Over 25 years of family-owned customer care in our local community. Hassle-free exchanges.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3.5">
            <div className="p-2.5 rounded-lg bg-zinc-800 text-amber-400 shrink-0">
              <Award className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-zinc-100 font-semibold text-sm">Flexible Payment Options</h4>
              <p className="text-zinc-400 text-xs mt-1 leading-relaxed">
                Cash on Delivery (COD), Khalti, eSewa, and all major digital wallets and cards supported.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Main Footer Links */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 grid grid-cols-2 md:grid-cols-5 gap-8">
        <div className="col-span-2">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-amber-600 flex items-center justify-center text-white font-bold text-sm">
              RP
            </div>
            <div className="flex flex-col">
              <span className="font-display text-base font-extrabold text-zinc-100 tracking-tight leading-tight">
                {STORE_NAME}
              </span>
              <span className="text-[10px] uppercase font-bold tracking-wider text-amber-500 leading-none">
                Neighborhood General Store
              </span>
            </div>
          </div>
          <p className="mt-3 text-xs text-zinc-400 max-w-sm leading-relaxed">
            Your comprehensive everyday general store. From morning tea and kitchen staples to school notebooks, cleaning supplies, batteries, hardware, and personal hygiene products.
          </p>
          <div className="mt-4 flex items-center gap-2 text-xs text-zinc-500">
            <span>Verified Neighborhood Retailer · PAN: 301294821</span>
          </div>
        </div>

        <div>
          <h5 className="font-semibold text-xs uppercase tracking-wider text-zinc-200">Store Aisles</h5>
          <ul className="mt-3 space-y-2 text-xs">
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('food-grocery');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Food & Daily Grocery
              </button>
            </li>
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('personal-care');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Personal Care & Hygiene
              </button>
            </li>
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('household');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Household & Detergents
              </button>
            </li>
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('stationery');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Stationery & School Copies
              </button>
            </li>
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('electronics');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Electronics & LED Bulbs
              </button>
            </li>
            <li>
              <button
                onClick={() => {
                  setSelectedCategory('all');
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors"
              >
                Browse All Aisles
              </button>
            </li>
          </ul>
        </div>

        <div>
          <h5 className="font-semibold text-xs uppercase tracking-wider text-zinc-200">Customer Care</h5>
          <ul className="mt-3 space-y-2 text-xs">
            <li>
              <button onClick={() => setActivePage('tracking')} className="hover:text-amber-400 transition-colors">
                Track Active Order
              </button>
            </li>
            <li>
              <button onClick={() => setActivePage('mobile_simulator')} className="text-amber-400 hover:text-amber-300 transition-colors flex items-center gap-1 font-medium">
                <span>📱 Flutter Mobile App Simulator</span>
              </button>
            </li>
            <li>
              <button onClick={() => setActivePage('account')} className="hover:text-amber-400 transition-colors">
                Delivery Addresses
              </button>
            </li>
            <li>
              <button onClick={() => setActivePage('account')} className="hover:text-amber-400 transition-colors">
                Order History & Invoices
              </button>
            </li>
            <li>
              <span className="text-zinc-500">Store Phone: 01-5912345 / 9841234567</span>
            </li>
            <li>
              <span className="text-zinc-500">Open 7 Days: 6:30 AM – 9:30 PM</span>
            </li>
          </ul>
        </div>

        <div>
          <h5 className="font-semibold text-xs uppercase tracking-wider text-zinc-200">Delivery Hubs</h5>
          <ul className="mt-3 space-y-2 text-xs text-zinc-400">
            <li>Lalitpur: Jhamsikhel, Kupondole, Pulchowk, Jawalakhel</li>
            <li>Kathmandu: Thapathali, Tripureshwor, Baneshwor, Naxal</li>
            <li>Bhaktapur: Radhe Radhe, Suryabinayak</li>
            <li>Express Rider Radius: 8-12 km around store hub</li>
          </ul>
        </div>
      </div>

      <div className="border-t border-zinc-800/80 py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-zinc-500">
          <div>© {new Date().getFullYear()} {STORE_NAME}. All rights reserved.</div>
          <div className="flex items-center gap-4">
            <span>Neighborhood Delivery Policy</span>
            <span>·</span>
            <span>Terms & Conditions</span>
            <span>·</span>
            <span>Authentic Brand Guarantee</span>
          </div>
        </div>
      </div>
    </footer>
  );
};
