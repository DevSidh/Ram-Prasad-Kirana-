import React from 'react';
import { useStore } from '../../context/StoreContext';
import { ArrowRight } from 'lucide-react';

export const CategoryList: React.FC = () => {
  const { categories, selectedCategory, setSelectedCategory, setActivePage } = useStore();

  const handleSelect = (slug: string) => {
    setSelectedCategory(slug);
    setActivePage('market');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-10">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl sm:text-2xl font-display font-bold text-zinc-950">
            Explore Store Departments
          </h2>
          <p className="text-xs sm:text-sm text-zinc-500 mt-1">
            Browse all aisles — grocery, toiletries, cleaning, stationery, hardware, and everyday electronics.
          </p>
        </div>

        <button
          onClick={() => {
            setSelectedCategory('all');
            setActivePage('market');
          }}
          className="text-xs font-semibold text-emerald-800 hover:text-emerald-950 flex items-center gap-1 transition-colors cursor-pointer"
        >
          <span>View All Products</span>
          <ArrowRight className="w-3.5 h-3.5" />
        </button>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3.5 sm:gap-4">
        {categories.map((cat) => {
          const isActive = selectedCategory === cat.slug;
          return (
            <div
              key={cat.id}
              onClick={() => handleSelect(cat.slug)}
              className={`group relative rounded-xl overflow-hidden cursor-pointer border transition-all duration-200 flex flex-col justify-between ${
                isActive
                  ? 'border-emerald-600 ring-2 ring-emerald-600/20 shadow-sm'
                  : 'border-zinc-200/90 bg-white hover:border-zinc-300 hover:shadow-xs'
              }`}
            >
              <div className="aspect-square bg-zinc-100 overflow-hidden relative">
                {cat.image ? (
                  <img
                    src={cat.image}
                    alt={cat.name}
                    referrerPolicy="no-referrer"
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center bg-zinc-100 text-zinc-400">
                    {cat.name.slice(0, 2)}
                  </div>
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-zinc-950/70 via-transparent to-transparent" />
                <div className="absolute bottom-2 left-2 right-2 text-white">
                  <h3 className="font-semibold text-xs leading-tight drop-shadow-xs">{cat.name}</h3>
                </div>
              </div>

              <div className="p-2.5 bg-white flex items-center justify-between text-[11px] text-zinc-500">
                <span className="truncate">{cat.itemCount} items</span>
                <span className="text-emerald-700 font-semibold group-hover:translate-x-0.5 transition-transform">
                  →
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
};
