import React from 'react';
import { useStore } from '../../context/StoreContext';
import { HERO_IMAGE, STORE_NAME } from '../../data/initialData';
import { Search, ShieldCheck, Clock, ArrowRight, Store, CheckCircle } from 'lucide-react';

export const HeroBanner: React.FC = () => {
  const { searchQuery, setSearchQuery, setActivePage } = useStore();

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setActivePage('market');
  };

  return (
    <section className="relative bg-zinc-950 text-white overflow-hidden rounded-2xl mx-4 sm:mx-6 lg:mx-8 my-6">
      {/* Background Image with Scrim */}
      <div className="absolute inset-0 z-0">
        <img
          src={HERO_IMAGE}
          alt={STORE_NAME}
          referrerPolicy="no-referrer"
          className="w-full h-full object-cover object-center opacity-35 scale-102"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-zinc-950 via-zinc-950/85 to-zinc-950/40" />
        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-transparent" />
      </div>

      {/* Hero Content */}
      <div className="relative z-10 max-w-7xl mx-auto px-6 sm:px-10 py-14 sm:py-20 lg:py-24 flex flex-col justify-between">
        <div className="max-w-2xl">
          {/* Official Business Header Badge */}
          <div className="inline-flex items-center gap-2 bg-amber-500/10 border border-amber-500/30 px-3 py-1 rounded-full text-xs font-semibold text-amber-400 mb-4 tracking-wide">
            <Store className="w-3.5 h-3.5 text-amber-400" />
            <span>ESTABLISHED 1999 · TRUSTED NEIGHBORHOOD GENERAL STORE</span>
          </div>

          <h1 className="text-3xl sm:text-5xl lg:text-6xl font-display font-black tracking-tight leading-[1.1] text-zinc-50 text-balance">
            {STORE_NAME.toUpperCase()}
          </h1>

          <p className="mt-4 text-sm sm:text-base text-zinc-300 leading-relaxed max-w-xl">
            Everything your home, office, and kitchen needs in one place. From daily rice, oil & spices to school notebooks, toiletries, cleaning detergents, LED bulbs, hardware and electronics.
          </p>

          {/* Quick Search Form */}
          <form
            onSubmit={handleSearchSubmit}
            className="mt-7 flex flex-col sm:flex-row items-stretch sm:items-center gap-2 bg-white/10 backdrop-blur-md p-1.5 rounded-xl border border-white/20 max-w-xl shadow-xl"
          >
            <div className="flex items-center flex-1 px-3 py-2">
              <Search className="w-4 h-4 text-zinc-300 shrink-0 mr-2" />
              <input
                type="text"
                placeholder="Search products (toothpaste, notebook, bulb, detergent)..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-transparent text-sm text-white placeholder:text-zinc-400 focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="px-5 py-2.5 bg-amber-600 hover:bg-amber-500 text-white rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 transition-colors cursor-pointer shrink-0"
            >
              <span>Search Store</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </form>

          {/* Popular General Store Tags */}
          <div className="mt-4 flex flex-wrap items-center gap-2 text-xs text-zinc-400">
            <span className="text-zinc-500">Popular:</span>
            {[
              'Classmate Notebook',
              'Surf Excel Detergent',
              'Colgate Toothpaste',
              'Philips 12W LED Bulb',
              'Duracell Battery',
              'India Gate Basmati',
            ].map((item) => (
              <button
                key={item}
                type="button"
                onClick={() => {
                  setSearchQuery(item);
                  setActivePage('market');
                }}
                className="hover:text-amber-400 transition-colors text-zinc-300 cursor-pointer bg-white/5 hover:bg-white/10 px-2 py-0.5 rounded text-[11px]"
              >
                {item}
              </button>
            ))}
          </div>
        </div>

        {/* Floating Quick Trust Indicators */}
        <div className="mt-12 pt-6 border-t border-zinc-800/80 flex flex-wrap items-center gap-6 sm:gap-10 text-xs text-zinc-300">
          <div className="flex items-center gap-2">
            <Clock className="w-4 h-4 text-amber-400" />
            <span>Express 45-Min Neighborhood Delivery</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-amber-400" />
            <span>100% Original Brand Warranty</span>
          </div>
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-amber-400" />
            <span>Cash on Delivery & Khalti/eSewa</span>
          </div>
        </div>
      </div>
    </section>
  );
};
