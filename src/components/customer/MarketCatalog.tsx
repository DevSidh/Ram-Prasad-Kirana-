import React, { useState, useMemo } from 'react';
import { useStore } from '../../context/StoreContext';
import { ProductCard } from './ProductCard';
import {
  Filter,
  SlidersHorizontal,
  X,
  LayoutGrid,
  List as ListIcon,
  Search,
  Check,
  Star,
} from 'lucide-react';

export const MarketCatalog: React.FC = () => {
  const {
    products,
    categories,
    selectedCategory,
    setSelectedCategory,
    searchQuery,
    setSearchQuery,
    formatPrice,
  } = useStore();

  const [selectedBrand, setSelectedBrand] = useState<string>('all');
  const [selectedSubcategory, setSelectedSubcategory] = useState<string>('all');
  const [inStockOnly, setInStockOnly] = useState<boolean>(false);
  const [organicOnly, setOrganicOnly] = useState<boolean>(false);
  const [minRating, setMinRating] = useState<number>(0);
  const [maxPrice, setMaxPrice] = useState<number>(2500);
  const [sortBy, setSortBy] = useState<string>('popular');
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [isMobileFilterOpen, setIsMobileFilterOpen] = useState<boolean>(false);

  // Extract unique brands
  const brands = useMemo(() => {
    const list = Array.from(new Set(products.map((p) => p.brand))).filter(Boolean);
    return ['all', ...list];
  }, [products]);

  // Extract subcategories based on category
  const subcategories = useMemo(() => {
    const relevant =
      selectedCategory === 'all'
        ? products
        : products.filter((p) => p.categoryId === selectedCategory);
    const set = Array.from(new Set(relevant.map((p) => p.subcategory))).filter(Boolean);
    return ['all', ...set];
  }, [products, selectedCategory]);

  // Filtered & Sorted products
  const filteredProducts = useMemo(() => {
    let result = [...products];

    // Search query across name, description, brand, origin, SKU, barcode, subcategory, specifications, and tags
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.description.toLowerCase().includes(q) ||
          p.brand.toLowerCase().includes(q) ||
          (p.origin && p.origin.toLowerCase().includes(q)) ||
          p.sku.toLowerCase().includes(q) ||
          (p.barcode && p.barcode.toLowerCase().includes(q)) ||
          p.subcategory.toLowerCase().includes(q) ||
          (p.specifications && p.specifications.toLowerCase().includes(q)) ||
          p.tags.some((t) => t.toLowerCase().includes(q))
      );
    }

    // Category
    if (selectedCategory !== 'all') {
      result = result.filter((p) => p.categoryId === selectedCategory);
    }

    // Subcategory
    if (selectedSubcategory !== 'all') {
      result = result.filter((p) => p.subcategory === selectedSubcategory);
    }

    // Brand
    if (selectedBrand !== 'all') {
      result = result.filter((p) => p.brand === selectedBrand);
    }

    // In stock
    if (inStockOnly) {
      result = result.filter((p) => p.stock > 0);
    }

    // Organic
    if (organicOnly) {
      result = result.filter((p) => p.isOrganic);
    }

    // Rating
    if (minRating > 0) {
      result = result.filter((p) => p.rating >= minRating);
    }

    // Price
    result = result.filter((p) => p.price <= maxPrice);

    // Sorting
    if (sortBy === 'price_asc') {
      result.sort((a, b) => a.price - b.price);
    } else if (sortBy === 'price_desc') {
      result.sort((a, b) => b.price - a.price);
    } else if (sortBy === 'rating') {
      result.sort((a, b) => b.rating - a.rating);
    } else if (sortBy === 'newest') {
      result.sort((a, b) => (b.isNewArrival ? 1 : 0) - (a.isNewArrival ? 1 : 0));
    } else {
      // popular
      result.sort((a, b) => b.reviewCount - a.reviewCount);
    }

    return result;
  }, [
    products,
    searchQuery,
    selectedCategory,
    selectedSubcategory,
    selectedBrand,
    inStockOnly,
    organicOnly,
    minRating,
    maxPrice,
    sortBy,
  ]);

  const resetAllFilters = () => {
    setSelectedCategory('all');
    setSelectedSubcategory('all');
    setSelectedBrand('all');
    setInStockOnly(false);
    setOrganicOnly(false);
    setMinRating(0);
    setMaxPrice(1500);
    setSearchQuery('');
  };

  const hasActiveFilters =
    selectedCategory !== 'all' ||
    selectedSubcategory !== 'all' ||
    selectedBrand !== 'all' ||
    inStockOnly ||
    organicOnly ||
    minRating > 0 ||
    maxPrice < 1500 ||
    Boolean(searchQuery.trim());

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Header bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-zinc-200">
        <div>
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-zinc-950">
            General Store Catalog
          </h1>
          <p className="text-xs sm:text-sm text-zinc-500 mt-1">
            Displaying <span className="font-semibold text-zinc-900 tabular-nums">{filteredProducts.length}</span> everyday items
            {selectedCategory !== 'all' && ` in ${categories.find(c => c.slug === selectedCategory)?.name || selectedCategory}`}
          </p>
        </div>

        {/* Right utility toolbar */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Mobile Filter Trigger */}
          <button
            onClick={() => setIsMobileFilterOpen(true)}
            className="lg:hidden px-3.5 py-2 bg-zinc-100 hover:bg-zinc-200 text-zinc-800 rounded-lg text-xs font-semibold flex items-center gap-2"
          >
            <Filter className="w-3.5 h-3.5" />
            <span>Filters ({hasActiveFilters ? 'Active' : 'All'})</span>
          </button>

          {/* Sort Selector */}
          <div className="flex items-center gap-2 text-xs">
            <span className="text-zinc-500 hidden sm:inline">Sort:</span>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="bg-white border border-zinc-300 rounded-lg px-3 py-1.5 text-xs text-zinc-800 font-medium focus:outline-emerald-600 cursor-pointer"
            >
              <option value="popular">Most Popular</option>
              <option value="newest">New Arrivals</option>
              <option value="price_asc">Price: Low to High</option>
              <option value="price_desc">Price: High to Low</option>
              <option value="rating">Highest Rated</option>
            </select>
          </div>

          {/* View Mode Toggle */}
          <div className="flex items-center bg-zinc-100 p-1 rounded-lg">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-1.5 rounded transition-colors ${
                viewMode === 'grid' ? 'bg-white text-zinc-900 shadow-xs' : 'text-zinc-500 hover:text-zinc-800'
              }`}
              title="Grid View"
            >
              <LayoutGrid className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-1.5 rounded transition-colors ${
                viewMode === 'list' ? 'bg-white text-zinc-900 shadow-xs' : 'text-zinc-500 hover:text-zinc-800'
              }`}
              title="List View"
            >
              <ListIcon className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      </div>

      {/* Main Layout Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8 mt-6">
        {/* Desktop Sidebar Filters */}
        <aside className="hidden lg:block space-y-6">
          <div className="flex items-center justify-between pb-3 border-b border-zinc-200">
            <h3 className="font-semibold text-xs uppercase tracking-wider text-zinc-800">Filter Aisles</h3>
            {hasActiveFilters && (
              <button
                onClick={resetAllFilters}
                className="text-xs text-emerald-700 hover:text-emerald-900 font-medium cursor-pointer"
              >
                Clear All
              </button>
            )}
          </div>

          {/* Category Filter */}
          <div>
            <h4 className="text-xs font-bold text-zinc-900 mb-2.5">Category</h4>
            <div className="space-y-1">
              <button
                onClick={() => setSelectedCategory('all')}
                className={`w-full text-left text-xs px-2.5 py-1.5 rounded-md flex items-center justify-between transition-colors ${
                  selectedCategory === 'all'
                    ? 'bg-emerald-50 text-emerald-900 font-semibold'
                    : 'text-zinc-600 hover:bg-zinc-100'
                }`}
              >
                <span>All Aisles</span>
                <span className="text-[10px] text-zinc-400">{products.length}</span>
              </button>
              {categories.map((c) => (
                <button
                  key={c.id}
                  onClick={() => setSelectedCategory(c.slug)}
                  className={`w-full text-left text-xs px-2.5 py-1.5 rounded-md flex items-center justify-between transition-colors ${
                    selectedCategory === c.slug
                      ? 'bg-emerald-50 text-emerald-900 font-semibold'
                      : 'text-zinc-600 hover:bg-zinc-100'
                  }`}
                >
                  <span className="truncate">{c.name}</span>
                  <span className="text-[10px] text-zinc-400">{c.itemCount}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Subcategory Filter */}
          {subcategories.length > 2 && (
            <div>
              <h4 className="text-xs font-bold text-zinc-900 mb-2">Department Subcategory</h4>
              <select
                value={selectedSubcategory}
                onChange={(e) => setSelectedSubcategory(e.target.value)}
                className="w-full text-xs p-2 rounded-lg border border-zinc-300 bg-white"
              >
                <option value="all">All Subcategories</option>
                {subcategories.filter((s) => s !== 'all').map((sub) => (
                  <option key={sub} value={sub}>
                    {sub}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Price Range */}
          <div>
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="font-bold text-zinc-900">Max Price</span>
              <span className="font-semibold text-emerald-800 tabular-nums font-mono">
                {formatPrice(maxPrice)}
              </span>
            </div>
            <input
              type="range"
              min="80"
              max="1500"
              step="20"
              value={maxPrice}
              onChange={(e) => setMaxPrice(Number(e.target.value))}
              className="w-full accent-emerald-600 cursor-pointer"
            />
          </div>

          {/* Dietary & Freshness Toggles */}
          <div className="space-y-2.5 pt-2 border-t border-zinc-100">
            <h4 className="text-xs font-bold text-zinc-900">Preferences</h4>
            <label className="flex items-center gap-2 text-xs text-zinc-700 cursor-pointer">
              <input
                type="checkbox"
                checked={organicOnly}
                onChange={(e) => setOrganicOnly(e.target.checked)}
                className="rounded accent-emerald-600"
              />
              <span>Certified Organic Only</span>
            </label>
            <label className="flex items-center gap-2 text-xs text-zinc-700 cursor-pointer">
              <input
                type="checkbox"
                checked={inStockOnly}
                onChange={(e) => setInStockOnly(e.target.checked)}
                className="rounded accent-emerald-600"
              />
              <span>In Stock Only</span>
            </label>
          </div>

          {/* Brand Filter */}
          <div>
            <h4 className="text-xs font-bold text-zinc-900 mb-2">Orchards & Producers</h4>
            <div className="max-h-40 overflow-y-auto space-y-1 pr-1 text-xs text-zinc-600">
              {brands.map((b) => (
                <button
                  key={b}
                  onClick={() => setSelectedBrand(b)}
                  className={`w-full text-left px-2 py-1 rounded transition-colors ${
                    selectedBrand === b
                      ? 'bg-emerald-50 text-emerald-900 font-semibold'
                      : 'hover:bg-zinc-100'
                  }`}
                >
                  {b === 'all' ? 'All Producers' : b}
                </button>
              ))}
            </div>
          </div>

          {/* Minimum Rating */}
          <div>
            <h4 className="text-xs font-bold text-zinc-900 mb-2">Customer Rating</h4>
            <div className="flex items-center gap-1.5">
              {[0, 4, 4.8].map((r) => (
                <button
                  key={r}
                  onClick={() => setMinRating(r)}
                  className={`px-2.5 py-1 text-xs rounded-md border transition-colors ${
                    minRating === r
                      ? 'border-emerald-700 bg-emerald-50 text-emerald-900 font-semibold'
                      : 'border-zinc-200 text-zinc-600 hover:bg-zinc-50'
                  }`}
                >
                  {r === 0 ? 'Any' : `${r}★ & up`}
                </button>
              ))}
            </div>
          </div>
        </aside>

        {/* Product Catalog Display */}
        <main className="lg:col-span-3">
          {/* Active Search & Filter chips bar */}
          {hasActiveFilters && (
            <div className="mb-4 flex flex-wrap items-center gap-2 text-xs">
              <span className="text-zinc-400">Active filters:</span>
              {searchQuery && (
                <span className="bg-zinc-100 text-zinc-700 px-2 py-0.5 rounded flex items-center gap-1">
                  Query: {searchQuery}
                  <button onClick={() => setSearchQuery('')} className="hover:text-zinc-950">
                    ×
                  </button>
                </span>
              )}
              {selectedCategory !== 'all' && (
                <span className="bg-zinc-100 text-zinc-700 px-2 py-0.5 rounded flex items-center gap-1">
                  Category: {selectedCategory}
                  <button onClick={() => setSelectedCategory('all')} className="hover:text-zinc-950">
                    ×
                  </button>
                </span>
              )}
              {organicOnly && (
                <span className="bg-emerald-50 text-emerald-800 px-2 py-0.5 rounded flex items-center gap-1">
                  Organic
                  <button onClick={() => setOrganicOnly(false)}>×</button>
                </span>
              )}
              {inStockOnly && (
                <span className="bg-zinc-100 text-zinc-700 px-2 py-0.5 rounded flex items-center gap-1">
                  In Stock
                  <button onClick={() => setInStockOnly(false)}>×</button>
                </span>
              )}
              <button
                onClick={resetAllFilters}
                className="text-emerald-700 hover:underline font-semibold ml-1"
              >
                Reset All
              </button>
            </div>
          )}

          {/* Empty State */}
          {filteredProducts.length === 0 ? (
            <div className="py-16 text-center border border-dashed border-zinc-300 rounded-2xl bg-white p-8">
              <Search className="w-10 h-10 mx-auto text-zinc-400 mb-3" />
              <h3 className="text-base font-semibold text-zinc-900">No matching groceries found</h3>
              <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
                We couldn't find items matching your selected criteria. Try adjusting your search or clearing active filters.
              </p>
              <button
                onClick={resetAllFilters}
                className="mt-4 px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white rounded-lg text-xs font-semibold cursor-pointer"
              >
                Clear Filters
              </button>
            </div>
          ) : viewMode === 'grid' ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
              {filteredProducts.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          ) : (
            <div className="space-y-3">
              {filteredProducts.map((product) => (
                <div
                  key={product.id}
                  className="bg-white border border-zinc-200 rounded-xl p-4 flex flex-col sm:flex-row items-center justify-between gap-4 hover:shadow-xs transition-shadow"
                >
                  <div className="flex items-center gap-4 w-full sm:w-auto">
                    <img
                      src={product.image}
                      alt={product.name}
                      referrerPolicy="no-referrer"
                      className="w-20 h-20 rounded-lg object-cover bg-zinc-50 shrink-0"
                    />
                    <div>
                      <div className="text-xs text-zinc-400">{product.brand} · {product.origin}</div>
                      <h4 className="text-sm font-semibold text-zinc-900 mt-0.5">{product.name}</h4>
                      <div className="text-xs text-zinc-500 mt-1">{product.unit}</div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between sm:justify-end gap-6 w-full sm:w-auto pt-3 sm:pt-0 border-t sm:border-t-0 border-zinc-100">
                    <div className="text-right">
                      <div className="text-base font-bold text-zinc-950 tabular-nums font-mono">
                        {formatPrice(product.price)}
                      </div>
                      <div className="text-[11px] text-zinc-400">{product.stock > 0 ? 'In Stock' : 'Out of Stock'}</div>
                    </div>

                    <ProductCard product={product} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </main>
      </div>

      {/* Mobile Filters Drawer */}
      {isMobileFilterOpen && (
        <div className="fixed inset-0 z-50 bg-zinc-950/50 backdrop-blur-xs flex justify-end">
          <div className="bg-white w-full max-w-xs h-full p-6 overflow-y-auto flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between pb-4 border-b border-zinc-200 mb-4">
                <h3 className="font-semibold text-sm text-zinc-900">Filters</h3>
                <button onClick={() => setIsMobileFilterOpen(false)} className="text-zinc-500">
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Mobile Filter Options */}
              <div className="space-y-4">
                <div>
                  <h4 className="text-xs font-bold text-zinc-900 mb-2">Category</h4>
                  <select
                    value={selectedCategory}
                    onChange={(e) => setSelectedCategory(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                  >
                    <option value="all">All Aisles</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.slug}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <h4 className="text-xs font-bold text-zinc-900 mb-2">Dietary</h4>
                  <label className="flex items-center gap-2 text-xs text-zinc-700">
                    <input
                      type="checkbox"
                      checked={organicOnly}
                      onChange={(e) => setOrganicOnly(e.target.checked)}
                      className="rounded accent-emerald-600"
                    />
                    <span>Certified Organic Only</span>
                  </label>
                </div>

                <div>
                  <h4 className="text-xs font-bold text-zinc-900 mb-2">Availability</h4>
                  <label className="flex items-center gap-2 text-xs text-zinc-700">
                    <input
                      type="checkbox"
                      checked={inStockOnly}
                      onChange={(e) => setInStockOnly(e.target.checked)}
                      className="rounded accent-emerald-600"
                    />
                    <span>In Stock Only</span>
                  </label>
                </div>
              </div>
            </div>

            <div className="pt-4 border-t border-zinc-200 flex gap-2">
              <button
                onClick={resetAllFilters}
                className="flex-1 py-2 text-xs font-semibold text-zinc-600 bg-zinc-100 rounded-lg"
              >
                Reset
              </button>
              <button
                onClick={() => setIsMobileFilterOpen(false)}
                className="flex-1 py-2 text-xs font-semibold text-white bg-emerald-700 rounded-lg"
              >
                Apply Filters
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
