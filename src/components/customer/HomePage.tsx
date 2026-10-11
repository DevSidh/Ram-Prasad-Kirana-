import React from 'react';
import { useStore } from '../../context/StoreContext';
import { HeroBanner } from './HeroBanner';
import { CategoryList } from './CategoryList';
import { ProductCard } from './ProductCard';
import { STORE_NAME } from '../../data/initialData';
import {
  ArrowRight,
  Sparkles,
  Flame,
  Tag,
  Zap,
  BookOpen,
  Home as HomeIcon,
  ShoppingBag,
  ShieldCheck,
  Package,
} from 'lucide-react';

export const HomePage: React.FC = () => {
  const { products, setActivePage, setSelectedCategory } = useStore();

  const todaysDeals = products.filter((p) => p.isTodayDeal).slice(0, 6);
  const bestSellers = products.filter((p) => p.isBestSeller).slice(0, 6);
  const householdItems = products.filter((p) => p.categoryId === 'household').slice(0, 4);
  const personalCareItems = products.filter((p) => p.categoryId === 'personal-care').slice(0, 4);
  const stationeryItems = products.filter((p) => p.categoryId === 'stationery').slice(0, 4);
  const electronicsItems = products.filter((p) => p.categoryId === 'electronics').slice(0, 4);
  const groceryItems = products.filter((p) => p.categoryId === 'food-grocery').slice(0, 4);

  const handleExploreAll = (categorySlug: string = 'all') => {
    setSelectedCategory(categorySlug);
    setActivePage('market');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <div className="space-y-12 pb-16">
      {/* Hero Banner with Official Store Header & Search */}
      <HeroBanner />

      {/* Promotional Discount Voucher Strip */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-amber-700 text-white p-4 rounded-xl flex flex-col sm:flex-row items-center justify-between gap-3 text-xs shadow-xs">
          <div className="flex items-center gap-2.5">
            <span className="px-2 py-0.5 bg-amber-900 rounded font-bold uppercase tracking-wider text-[10px]">
              Store Coupon
            </span>
            <span className="font-semibold text-amber-50">
              Save 10% on everyday essentials & stationery with coupon <strong className="underline font-mono text-white">RAMPRASAD10</strong>
            </span>
          </div>

          <button
            onClick={() => handleExploreAll('all')}
            className="px-4 py-1.5 bg-white text-amber-950 font-bold rounded-lg text-xs hover:bg-amber-50 transition-colors whitespace-nowrap cursor-pointer"
          >
            Shop Deals
          </button>
        </div>
      </div>

      {/* Store Departments Carousel/Grid */}
      <CategoryList />

      {/* 1. Today's Deals Section */}
      {todaysDeals.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between mb-6">
            <div>
              <div className="flex items-center gap-1.5 text-xs font-bold text-rose-600 uppercase tracking-wider">
                <Tag className="w-3.5 h-3.5" />
                <span>Limited Stock · Discounted Prices</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
                Today's Special Deals
              </h2>
            </div>

            <button
              onClick={() => handleExploreAll('all')}
              className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
            >
              <span>See All Deals</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {todaysDeals.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        </section>
      )}

      {/* 2. Best Sellers */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-amber-600 uppercase tracking-wider">
              <Flame className="w-3.5 h-3.5" />
              <span>Customer Favorites</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
              Popular & Best Sellers
            </h2>
          </div>

          <button
            onClick={() => handleExploreAll('all')}
            className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <span>View All</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {bestSellers.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* 3. Household Essentials Shelf */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-blue-600 uppercase tracking-wider">
              <Sparkles className="w-3.5 h-3.5" />
              <span>Clean Home Solutions</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
              Household & Detergents
            </h2>
          </div>

          <button
            onClick={() => handleExploreAll('household')}
            className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <span>View Cleaning Aisle</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {householdItems.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* 4. Stationery & School Shelf */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-purple-600 uppercase tracking-wider">
              <BookOpen className="w-3.5 h-3.5" />
              <span>Classmate, Reynolds & Office Needs</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
              Stationery & School Supplies
            </h2>
          </div>

          <button
            onClick={() => handleExploreAll('stationery')}
            className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <span>Explore Stationery</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {stationeryItems.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* 5. Electronics & Daily Utility */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-amber-600 uppercase tracking-wider">
              <Zap className="w-3.5 h-3.5" />
              <span>Bulbs, Batteries, Cables & Locks</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
              Electronics & Daily Utilities
            </h2>
          </div>

          <button
            onClick={() => handleExploreAll('electronics')}
            className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <span>View Electronics</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {electronicsItems.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* 6. Food & Daily Grocery Staples */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-700 uppercase tracking-wider">
              <ShoppingBag className="w-3.5 h-3.5" />
              <span>Rice, Oil, Spices & Tea</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-0.5">
              Food & Kitchen Groceries
            </h2>
          </div>

          <button
            onClick={() => handleExploreAll('food-grocery')}
            className="text-xs font-semibold text-amber-700 hover:text-amber-800 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <span>Browse Grocery</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {groceryItems.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* 7. Neighborhood General Store Trust Callout */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-4">
        <div className="bg-zinc-900 text-white rounded-3xl p-8 sm:p-12 relative overflow-hidden border border-zinc-800">
          <div className="max-w-2xl relative z-10">
            <span className="text-xs font-bold uppercase tracking-wider text-amber-400">
              The {STORE_NAME} Neighborhood Commitment
            </span>
            <h3 className="text-2xl sm:text-4xl font-display font-bold text-zinc-50 mt-2 leading-tight">
              One order. Every household essential. At your gate in 45 minutes.
            </h3>
            <p className="mt-4 text-xs sm:text-sm text-zinc-400 leading-relaxed">
              Why make multiple trips to the stationery shop, hardware store, and ration depot? Ram Prasad General Store brings together authentic everyday consumer goods under one roof, with guaranteed MRP or lower pricing and friendly neighborhood delivery.
            </p>

            <div className="mt-8 flex flex-wrap gap-4 text-xs font-medium">
              <button
                onClick={() => handleExploreAll('stationery')}
                className="px-5 py-2.5 bg-amber-600 hover:bg-amber-500 text-white rounded-xl font-bold transition-colors cursor-pointer"
              >
                Order School & Office Stationery
              </button>
              <button
                onClick={() => handleExploreAll('household')}
                className="px-5 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-200 rounded-xl font-semibold transition-colors cursor-pointer"
              >
                Stock Up On Detergents & Cleaners
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};
