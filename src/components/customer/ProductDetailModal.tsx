import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { STORE_NAME } from '../../data/initialData';
import {
  X,
  Star,
  Heart,
  Plus,
  Minus,
  ShieldCheck,
  Truck,
  RotateCcw,
  Layers,
  Calendar,
  Barcode,
  Sparkles,
} from 'lucide-react';

export const ProductDetailModal: React.FC = () => {
  const {
    products,
    activeProductModalId,
    setActiveProductModalId,
    formatPrice,
    addToCart,
    toggleWishlist,
    isWishlisted,
    reviews,
    addReview,
    setIsCartDrawerOpen,
    setActivePage,
  } = useStore();

  const [quantity, setQuantity] = useState(1);
  const [selectedVariantIndex, setSelectedVariantIndex] = useState(0);
  const [newReviewRating, setNewReviewRating] = useState(5);
  const [newReviewComment, setNewReviewComment] = useState('');
  const [newReviewAuthor, setNewReviewAuthor] = useState('');
  const [reviewSubmitted, setReviewSubmitted] = useState(false);

  if (!activeProductModalId) return null;

  const product = products.find((p) => p.id === activeProductModalId);
  if (!product) return null;

  const hasVariants = product.variants && product.variants.length > 0;
  const currentVariant = hasVariants ? product.variants![selectedVariantIndex] : null;
  const activePrice = currentVariant ? currentVariant.price : product.price;
  const activeSku = currentVariant && currentVariant.sku ? currentVariant.sku : product.sku;

  const productReviews = reviews.filter((r) => r.productId === product.id);
  const isSaved = isWishlisted(product.id);

  const handleAddToCart = () => {
    addToCart(
      product,
      quantity,
      currentVariant ? currentVariant.name : product.unit,
      currentVariant ? currentVariant.name : undefined,
      currentVariant ? currentVariant.price : undefined
    );
    setIsCartDrawerOpen(true);
  };

  const handleBuyNow = () => {
    addToCart(
      product,
      quantity,
      currentVariant ? currentVariant.name : product.unit,
      currentVariant ? currentVariant.name : undefined,
      currentVariant ? currentVariant.price : undefined
    );
    setActiveProductModalId(null);
    setActivePage('checkout');
  };

  const handleReviewSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newReviewComment.trim()) return;
    addReview(product.id, newReviewRating, newReviewComment, newReviewAuthor.trim() || 'Verified Customer');
    setNewReviewComment('');
    setNewReviewAuthor('');
    setReviewSubmitted(true);
    setTimeout(() => setReviewSubmitted(false), 3000);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-xs overflow-y-auto animate-in fade-in duration-200"
      onClick={() => setActiveProductModalId(null)}
    >
      <div
        className="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto border border-zinc-200 shadow-2xl relative my-8"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close Button */}
        <button
          onClick={() => setActiveProductModalId(null)}
          className="absolute top-4 right-4 z-10 p-2 rounded-full bg-zinc-100 hover:bg-zinc-200 text-zinc-600 transition-colors"
          title="Close"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 p-6 sm:p-8">
          {/* Left Column: Product Image & Badges */}
          <div>
            <div className="aspect-4/3 rounded-xl overflow-hidden bg-zinc-50 border border-zinc-100 relative">
              <img
                src={product.image}
                alt={product.name}
                referrerPolicy="no-referrer"
                className="w-full h-full object-cover"
              />
              {product.warranty && (
                <div className="absolute top-3 left-3 bg-amber-500/90 text-white text-xs font-bold px-2.5 py-1 rounded-md shadow-xs flex items-center gap-1">
                  <ShieldCheck className="w-3.5 h-3.5" />
                  <span>{product.warranty}</span>
                </div>
              )}
            </div>

            {/* Value Guarantees */}
            <div className="mt-5 grid grid-cols-3 gap-3 border-t border-zinc-100 pt-4 text-center">
              <div className="p-2 bg-zinc-50 rounded-lg">
                <Truck className="w-4 h-4 mx-auto text-amber-700" />
                <div className="text-[11px] font-bold text-zinc-800 mt-1">45-Min Express</div>
                <div className="text-[10px] text-zinc-500">Local delivery</div>
              </div>
              <div className="p-2 bg-zinc-50 rounded-lg">
                <ShieldCheck className="w-4 h-4 mx-auto text-amber-700" />
                <div className="text-[11px] font-bold text-zinc-800 mt-1">100% Genuine</div>
                <div className="text-[10px] text-zinc-500">Authorized source</div>
              </div>
              <div className="p-2 bg-zinc-50 rounded-lg">
                <RotateCcw className="w-4 h-4 mx-auto text-amber-700" />
                <div className="text-[11px] font-bold text-zinc-800 mt-1">Easy Exchange</div>
                <div className="text-[10px] text-zinc-500">Neighborhood care</div>
              </div>
            </div>

            {/* Specifications Box */}
            {product.specifications && (
              <div className="mt-4 p-4 rounded-xl bg-amber-50/60 border border-amber-200/60 text-xs">
                <h4 className="font-bold uppercase tracking-wider text-amber-900 mb-1 flex items-center gap-1.5">
                  <Sparkles className="w-3.5 h-3.5 text-amber-700" />
                  <span>Specifications & Features</span>
                </h4>
                <p className="text-zinc-700 leading-relaxed">{product.specifications}</p>
              </div>
            )}

            {/* Nutrition / Ingredients if available */}
            {product.ingredients && (
              <div className="mt-3 p-3 rounded-xl bg-zinc-50 border border-zinc-200 text-xs">
                <span className="font-bold text-zinc-800">Ingredients: </span>
                <span className="text-zinc-600">{product.ingredients}</span>
              </div>
            )}
          </div>

          {/* Right Column: Information, Pricing, Purchase actions */}
          <div className="flex flex-col justify-between">
            <div>
              {/* Brand and Origin */}
              <div className="text-xs text-zinc-500 flex flex-wrap items-center gap-2">
                <span className="font-bold uppercase tracking-wider text-amber-700">
                  {product.brand}
                </span>
                <span>·</span>
                <span className="text-zinc-600">{product.subcategory}</span>
                {product.origin && (
                  <>
                    <span>·</span>
                    <span className="text-zinc-500">{product.origin}</span>
                  </>
                )}
              </div>

              {/* Title */}
              <h1 className="text-xl sm:text-2xl font-display font-extrabold text-zinc-950 mt-1 leading-snug">
                {product.name}
              </h1>

              {/* Rating */}
              <div className="flex items-center gap-2 mt-2">
                <div className="flex items-center text-amber-500">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      className={`w-4 h-4 ${
                        i < Math.floor(product.rating) ? 'fill-current' : 'text-zinc-300'
                      }`}
                    />
                  ))}
                </div>
                <span className="text-sm font-bold text-zinc-900 tabular-nums">
                  {product.rating}
                </span>
                <span className="text-xs text-zinc-500">
                  ({product.reviewCount} customer reviews)
                </span>
              </div>

              {/* Pricing Module */}
              <div className="mt-4 p-4 rounded-xl bg-zinc-50 border border-zinc-200/80">
                <div className="flex items-baseline gap-3">
                  <span className="text-2xl font-black text-zinc-950 tabular-nums font-mono">
                    {formatPrice(activePrice)}
                  </span>
                  {product.originalPrice && product.originalPrice > activePrice && (
                    <span className="text-sm text-zinc-400 line-through tabular-nums font-mono">
                      {formatPrice(product.originalPrice)}
                    </span>
                  )}
                  {product.discountPercent && product.discountPercent > 0 && (
                    <span className="text-xs font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded">
                      Save {product.discountPercent}%
                    </span>
                  )}
                </div>
                <div className="mt-1 text-xs text-zinc-600 flex items-center justify-between">
                  <span>
                    Packaging: <strong className="text-zinc-900">{currentVariant ? currentVariant.name : product.unit}</strong>
                  </span>
                  <span className="text-[11px] font-mono text-zinc-500 flex items-center gap-1">
                    <Barcode className="w-3.5 h-3.5" />
                    <span>SKU: {activeSku}</span>
                  </span>
                </div>
              </div>

              {/* Variants Selector */}
              {hasVariants && (
                <div className="mt-4">
                  <label className="text-xs font-bold uppercase tracking-wider text-zinc-700 flex items-center gap-1.5 mb-2">
                    <Layers className="w-3.5 h-3.5 text-amber-700" />
                    <span>Select Size / Package Option:</span>
                  </label>
                  <div className="grid grid-cols-2 gap-2">
                    {product.variants!.map((variant, idx) => (
                      <button
                        key={variant.id}
                        type="button"
                        onClick={() => setSelectedVariantIndex(idx)}
                        className={`p-2.5 rounded-lg border text-left transition-all cursor-pointer ${
                          selectedVariantIndex === idx
                            ? 'border-amber-600 bg-amber-50/80 ring-2 ring-amber-600/20'
                            : 'border-zinc-200 hover:border-zinc-300 bg-white'
                        }`}
                      >
                        <div className="font-semibold text-xs text-zinc-900">{variant.name}</div>
                        <div className="text-xs font-bold text-amber-800 font-mono mt-0.5">
                          {formatPrice(variant.price)}
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Description */}
              <p className="mt-4 text-xs sm:text-sm text-zinc-600 leading-relaxed">
                {product.description}
              </p>

              {/* Expiry Date */}
              {product.expiryDate && (
                <div className="mt-3 flex items-center gap-2 text-xs text-zinc-600 bg-zinc-50 px-3 py-1.5 rounded-lg border border-zinc-200">
                  <Calendar className="w-3.5 h-3.5 text-emerald-700" />
                  <span>
                    Best Before / Expiry: <strong className="text-zinc-800">{product.expiryDate}</strong>
                  </span>
                </div>
              )}

              {/* Tags */}
              <div className="mt-3 flex flex-wrap gap-1.5">
                {product.tags.map((tag) => (
                  <span
                    key={tag}
                    className="text-[11px] text-zinc-600 bg-zinc-100 px-2 py-0.5 rounded"
                  >
                    #{tag}
                  </span>
                ))}
              </div>
            </div>

            {/* Purchase CTA Cluster */}
            <div className="mt-8 pt-4 border-t border-zinc-200">
              <div className="flex items-center gap-4 mb-4">
                <div className="text-xs font-semibold text-zinc-700">Quantity:</div>
                <div className="flex items-center border border-zinc-300 rounded-lg">
                  <button
                    type="button"
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="p-2 text-zinc-600 hover:text-zinc-900 transition-colors"
                  >
                    <Minus className="w-3.5 h-3.5" />
                  </button>
                  <span className="w-8 text-center text-sm font-bold tabular-nums">
                    {quantity}
                  </span>
                  <button
                    type="button"
                    disabled={quantity >= product.stock}
                    onClick={() => setQuantity(Math.min(product.stock, quantity + 1))}
                    className="p-2 text-zinc-600 hover:text-zinc-900 disabled:opacity-40 transition-colors"
                  >
                    <Plus className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div className="text-xs text-zinc-500">
                  {product.stock > 0 ? (
                    <span className="text-emerald-700 font-bold">✓ Ready for express delivery</span>
                  ) : (
                    <span className="text-rose-600 font-bold">Out of stock</span>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-3">
                <button
                  type="button"
                  disabled={product.stock <= 0}
                  onClick={handleAddToCart}
                  className="flex-1 py-3 px-4 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-sm font-bold flex items-center justify-center gap-2 transition-colors disabled:opacity-50 cursor-pointer shadow-xs"
                >
                  <Plus className="w-4 h-4" />
                  <span>Add to Bag</span>
                </button>

                <button
                  type="button"
                  disabled={product.stock <= 0}
                  onClick={handleBuyNow}
                  className="py-3 px-6 bg-zinc-900 hover:bg-zinc-800 text-white rounded-xl text-sm font-bold transition-colors disabled:opacity-50 cursor-pointer"
                >
                  Buy Now
                </button>

                <button
                  type="button"
                  onClick={() => toggleWishlist(product.id)}
                  className={`p-3 rounded-xl border transition-colors ${
                    isSaved
                      ? 'border-rose-300 bg-rose-50 text-rose-600'
                      : 'border-zinc-300 text-zinc-600 hover:border-zinc-400'
                  }`}
                  title="Wishlist"
                >
                  <Heart className={`w-5 h-5 ${isSaved ? 'fill-current' : ''}`} />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Customer Reviews Section */}
        <div className="border-t border-zinc-200 p-6 sm:p-8 bg-zinc-50/50">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-bold text-lg text-zinc-900">
              Customer Reviews ({productReviews.length})
            </h3>
            <span className="text-xs text-zinc-500">Verified customers of {STORE_NAME}</span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            {productReviews.length === 0 ? (
              <div className="col-span-2 text-center py-6 text-xs text-zinc-400">
                No reviews yet. Be the first to review this product!
              </div>
            ) : (
              productReviews.map((rev) => (
                <div
                  key={rev.id}
                  className="p-4 rounded-xl bg-white border border-zinc-200/80 shadow-2xs"
                >
                  <div className="flex items-center justify-between">
                    <div className="font-semibold text-xs text-zinc-900">{rev.userName}</div>
                    <div className="flex text-amber-500">
                      {[...Array(5)].map((_, i) => (
                        <Star
                          key={i}
                          className={`w-3.5 h-3.5 ${i < rev.rating ? 'fill-current' : 'text-zinc-200'}`}
                        />
                      ))}
                    </div>
                  </div>
                  <p className="text-xs text-zinc-600 mt-2 leading-relaxed">{rev.comment}</p>
                  <div className="mt-2 text-[10px] text-zinc-400 flex items-center justify-between">
                    <span>{rev.createdAt}</span>
                    <span className="text-emerald-700 font-medium">✓ Verified Purchase</span>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Add Review Form */}
          <form onSubmit={handleReviewSubmit} className="bg-white p-4 rounded-xl border border-zinc-200 shadow-2xs">
            <h4 className="font-semibold text-xs text-zinc-900 mb-2">Write a Customer Review</h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
              <input
                type="text"
                placeholder="Your Name"
                value={newReviewAuthor}
                onChange={(e) => setNewReviewAuthor(e.target.value)}
                className="text-xs px-3 py-2 border border-zinc-300 rounded-lg focus:outline-none focus:border-amber-600"
              />
              <div className="flex items-center gap-2">
                <span className="text-xs text-zinc-500">Rating:</span>
                <div className="flex items-center gap-1">
                  {[1, 2, 3, 4, 5].map((num) => (
                    <button
                      key={num}
                      type="button"
                      onClick={() => setNewReviewRating(num)}
                      className={`text-sm ${num <= newReviewRating ? 'text-amber-500' : 'text-zinc-300'}`}
                    >
                      ★
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <textarea
              placeholder="Share your experience with this item..."
              value={newReviewComment}
              onChange={(e) => setNewReviewComment(e.target.value)}
              rows={2}
              className="w-full text-xs p-3 border border-zinc-300 rounded-lg focus:outline-none focus:border-amber-600 mb-2"
            />
            <div className="flex items-center justify-between">
              {reviewSubmitted ? (
                <span className="text-xs text-emerald-700 font-bold">Review posted successfully!</span>
              ) : <div />}
              <button
                type="submit"
                className="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-xs font-bold transition-colors cursor-pointer"
              >
                Submit Review
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};
