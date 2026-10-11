import React from 'react';
import { Product } from '../../types';
import { useStore } from '../../context/StoreContext';
import { Plus, Minus, Heart, Star, ShieldCheck, Layers } from 'lucide-react';

interface ProductCardProps {
  product: Product;
}

export const ProductCard: React.FC<ProductCardProps> = ({ product }) => {
  const {
    formatPrice,
    addToCart,
    cart,
    updateQuantity,
    toggleWishlist,
    isWishlisted,
    setActiveProductModalId,
  } = useStore();

  const cartItem = cart.find((item) => item.productId === product.id);
  const isSaved = isWishlisted(product.id);
  const isOutOfStock = product.stock <= 0;
  const hasVariants = product.variants && product.variants.length > 0;

  return (
    <div className="group relative bg-white border border-zinc-200/90 rounded-xl overflow-hidden hover:shadow-md hover:border-zinc-300 transition-all duration-200 flex flex-col justify-between">
      {/* Top Image Container */}
      <div className="relative aspect-4/3 bg-zinc-50 overflow-hidden cursor-pointer">
        <img
          src={product.image}
          alt={product.name}
          referrerPolicy="no-referrer"
          onClick={() => setActiveProductModalId(product.id)}
          className="w-full h-full object-cover group-hover:scale-103 transition-transform duration-300"
        />

        {/* Wishlist Button */}
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            toggleWishlist(product.id);
          }}
          className={`absolute top-2.5 right-2.5 p-2 rounded-full backdrop-blur-md transition-all cursor-pointer ${
            isSaved
              ? 'bg-rose-50 text-rose-600 shadow-xs'
              : 'bg-white/80 text-zinc-500 hover:text-zinc-900 hover:bg-white'
          }`}
          title={isSaved ? 'Remove from wishlist' : 'Save to wishlist'}
        >
          <Heart className={`w-4 h-4 ${isSaved ? 'fill-current' : ''}`} />
        </button>

        {/* Badges / Discount */}
        {product.discountPercent && product.discountPercent > 0 ? (
          <div className="absolute top-2.5 left-2.5 text-[11px] font-bold tracking-wide text-white bg-amber-600 backdrop-blur-xs px-2 py-0.5 rounded shadow-xs">
            {product.discountPercent}% OFF
          </div>
        ) : product.warranty ? (
          <div className="absolute top-2.5 left-2.5 text-[11px] font-semibold tracking-wide text-zinc-900 bg-amber-100 border border-amber-300 px-2 py-0.5 rounded flex items-center gap-1 shadow-xs">
            <ShieldCheck className="w-3 h-3 text-amber-700" />
            <span>{product.warranty}</span>
          </div>
        ) : hasVariants ? (
          <div className="absolute top-2.5 left-2.5 text-[11px] font-semibold tracking-wide text-zinc-700 bg-white/90 border border-zinc-200 px-2 py-0.5 rounded flex items-center gap-1 shadow-xs">
            <Layers className="w-3 h-3 text-zinc-500" />
            <span>{product.variants!.length} Options</span>
          </div>
        ) : null}

        {/* Out of Stock overlay if applicable */}
        {isOutOfStock && (
          <div className="absolute inset-0 bg-white/70 backdrop-blur-xs flex items-center justify-center">
            <span className="text-xs font-bold uppercase tracking-wider text-zinc-700 bg-zinc-200 px-2.5 py-1 rounded">
              Out of Stock
            </span>
          </div>
        )}
      </div>

      {/* Product Details Section */}
      <div className="p-4 flex flex-col flex-1 justify-between">
        <div
          onClick={() => setActiveProductModalId(product.id)}
          className="cursor-pointer"
        >
          {/* Subtle Category & Unit metadata */}
          <div className="flex items-center justify-between text-xs text-zinc-500 mb-1">
            <span className="truncate font-medium text-amber-800">{product.brand}</span>
            <span className="shrink-0 font-mono text-[11px] bg-zinc-100 text-zinc-600 px-1.5 py-0.5 rounded">
              {product.unit}
            </span>
          </div>

          {/* Product Title */}
          <h3 className="font-semibold text-zinc-900 text-sm leading-snug line-clamp-2 group-hover:text-amber-800 transition-colors">
            {product.name}
          </h3>

          {/* Rating & Subcategory metadata */}
          <div className="flex items-center gap-1.5 mt-2 text-xs text-zinc-600">
            <div className="flex items-center text-amber-500">
              <Star className="w-3.5 h-3.5 fill-current" />
            </div>
            <span className="font-semibold text-zinc-900 tabular-nums">{product.rating}</span>
            <span className="text-zinc-400">({product.reviewCount})</span>
            <span aria-hidden="true" className="text-zinc-300">·</span>
            <span className="text-zinc-500 truncate">{product.subcategory}</span>
          </div>
        </div>

        {/* Pricing & Cart Action Module */}
        <div className="mt-4 pt-3 border-t border-zinc-100 flex items-center justify-between gap-2">
          <div>
            <div className="flex items-baseline gap-1.5">
              <span className="text-base font-bold text-zinc-950 tabular-nums font-mono">
                {formatPrice(product.price)}
              </span>
              {product.originalPrice && product.originalPrice > product.price && (
                <span className="text-xs text-zinc-400 line-through tabular-nums font-mono">
                  {formatPrice(product.originalPrice)}
                </span>
              )}
            </div>
            <div className="text-[11px] text-zinc-400">
              {product.stock > 0 && product.stock <= 8 ? (
                <span className="text-amber-600 font-medium">Only {product.stock} left</span>
              ) : (
                <span className="text-emerald-700 font-medium">In Stock</span>
              )}
            </div>
          </div>

          {/* Cart Stepper or Add Button */}
          {cartItem ? (
            <div className="flex items-center bg-amber-50 border border-amber-200 rounded-lg p-0.5">
              <button
                type="button"
                onClick={() => updateQuantity(product.id, cartItem.quantity - 1)}
                className="w-7 h-7 flex items-center justify-center text-amber-900 hover:bg-amber-100 rounded transition-colors"
                title="Decrease quantity"
              >
                <Minus className="w-3.5 h-3.5" />
              </button>
              <span className="w-6 text-center text-xs font-bold text-amber-950 tabular-nums">
                {cartItem.quantity}
              </span>
              <button
                type="button"
                disabled={cartItem.quantity >= product.stock}
                onClick={() => updateQuantity(product.id, cartItem.quantity + 1)}
                className="w-7 h-7 flex items-center justify-center text-amber-900 hover:bg-amber-100 rounded disabled:opacity-40 transition-colors"
                title="Increase quantity"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
          ) : hasVariants ? (
            <button
              type="button"
              disabled={isOutOfStock}
              onClick={() => setActiveProductModalId(product.id)}
              className="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-xs font-bold flex items-center gap-1 transition-colors cursor-pointer"
            >
              <span>Options</span>
            </button>
          ) : (
            <button
              type="button"
              disabled={isOutOfStock}
              onClick={() => addToCart(product, 1)}
              className="px-3 py-1.5 bg-zinc-900 hover:bg-amber-600 text-white rounded-lg text-xs font-semibold flex items-center gap-1 transition-colors disabled:opacity-40 disabled:hover:bg-zinc-900 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
