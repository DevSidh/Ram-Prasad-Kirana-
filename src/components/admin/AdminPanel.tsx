import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import { Product, OrderStatus, Coupon, Category } from '../../types';
import {
  BarChart3,
  Package,
  ShoppingCart,
  Users,
  Tag,
  AlertTriangle,
  Plus,
  Trash2,
  Edit2,
  Check,
  Search,
  TrendingUp,
  Truck,
  RotateCcw,
  DollarSign,
  Filter,
} from 'lucide-react';

export const AdminPanel: React.FC = () => {
  const {
    products,
    categories,
    orders,
    coupons,
    deliveryPersonnel,
    formatPrice,
    addProduct,
    updateProduct,
    deleteProduct,
    restockProduct,
    updateOrderStatus,
    assignDeliveryPerson,
    addCoupon,
    toggleCoupon,
    addCategory,
  } = useStore();

  const [activeAdminTab, setActiveAdminTab] = useState<
    'analytics' | 'products' | 'orders' | 'inventory' | 'coupons' | 'categories' | 'customers'
  >('analytics');

  // Search in products
  const [productSearch, setProductSearch] = useState('');
  const [selectedProductCategory, setSelectedProductCategory] = useState('all');

  // Add Product Modal
  const [isAddProductOpen, setIsAddProductOpen] = useState(false);
  const [newProdName, setNewProdName] = useState('');
  const [newProdCategory, setNewProdCategory] = useState('food-grocery');
  const [newProdSubcategory, setNewProdSubcategory] = useState('Rice & Grains');
  const [newProdBrand, setNewProdBrand] = useState('Generic Quality');
  const [newProdSku, setNewProdSku] = useState('');
  const [newProdBarcode, setNewProdBarcode] = useState('');
  const [newProdPrice, setNewProdPrice] = useState('250');
  const [newProdUnit, setNewProdUnit] = useState('1 piece');
  const [newProdStock, setNewProdStock] = useState('40');
  const [newProdDesc, setNewProdDesc] = useState('');
  const [newProdOrigin, setNewProdOrigin] = useState('');
  const [newProdSpecs, setNewProdSpecs] = useState('');
  const [newProdWarranty, setNewProdWarranty] = useState('');
  const [newProdExpiry, setNewProdExpiry] = useState('');
  const [newProdIngredients, setNewProdIngredients] = useState('');
  const [newProdSize, setNewProdSize] = useState('');
  const [newProdColor, setNewProdColor] = useState('');
  const [newProdMaterial, setNewProdMaterial] = useState('');

  // Order status filter
  const [orderStatusFilter, setOrderStatusFilter] = useState<string>('all');

  // Add Coupon form
  const [showAddCoupon, setShowAddCoupon] = useState(false);
  const [newCouponCode, setNewCouponCode] = useState('');
  const [newCouponDesc, setNewCouponDesc] = useState('');
  const [newCouponPercent, setNewCouponPercent] = useState('15');
  const [newCouponMin, setNewCouponMin] = useState('600');
  const [newCouponMax, setNewCouponMax] = useState('300');

  // Add Category form
  const [showAddCat, setShowAddCat] = useState(false);
  const [newCatName, setNewCatName] = useState('');
  const [newCatSlug, setNewCatSlug] = useState('');
  const [newCatDesc, setNewCatDesc] = useState('');
  const [newCatSubcategories, setNewCatSubcategories] = useState('');

  // Analytics Metrics
  const totalRevenue = orders.reduce((sum, ord) => sum + (ord.status !== 'cancelled' ? ord.total : 0), 0);
  const totalOrdersCount = orders.length;
  const lowStockProducts = products.filter((p) => p.stock <= p.minStockAlert);
  const activeOrders = orders.filter((o) => o.status !== 'delivered' && o.status !== 'cancelled');

  const handleCreateProduct = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProdName.trim()) return;

    const skuGenerated = newProdSku.trim() || `RPG-${newProdCategory.slice(0, 3).toUpperCase()}-${Math.floor(100 + Math.random() * 900)}`;

    addProduct({
      name: newProdName,
      categoryId: newProdCategory,
      subcategory: newProdSubcategory || 'General Store Product',
      brand: newProdBrand || 'Ram Prasad Store',
      sku: skuGenerated,
      barcode: newProdBarcode || `890${Math.floor(1000000000 + Math.random() * 9000000000)}`,
      price: Number(newProdPrice) || 100,
      unit: newProdUnit,
      stock: Number(newProdStock) || 20,
      minStockAlert: 8,
      description: newProdDesc || 'Everyday authentic consumer product from Ram Prasad General Store.',
      origin: newProdOrigin || 'Authorized Distributor',
      specifications: newProdSpecs || undefined,
      warranty: newProdWarranty || undefined,
      expiryDate: newProdExpiry || undefined,
      ingredients: newProdIngredients || undefined,
      size: newProdSize || undefined,
      color: newProdColor || undefined,
      material: newProdMaterial || undefined,
      image: '/src/assets/images/cat_household_care_1791378587148.jpg',
      tags: [newProdBrand, newProdCategory, newProdSubcategory].filter(Boolean),
    });

    setNewProdName('');
    setNewProdSpecs('');
    setNewProdWarranty('');
    setNewProdExpiry('');
    setNewProdIngredients('');
    setIsAddProductOpen(false);
  };

  const handleCreateCoupon = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCouponCode.trim()) return;
    addCoupon({
      code: newCouponCode.trim().toUpperCase(),
      description: newCouponDesc || `${newCouponPercent}% harvest discount`,
      discountPercent: Number(newCouponPercent) || 10,
      minOrderAmount: Number(newCouponMin) || 500,
      maxDiscount: Number(newCouponMax) || 250,
      active: true,
      usageCount: 0,
      expiryDate: '2026-12-31',
    });
    setNewCouponCode('');
    setShowAddCoupon(false);
  };

  const handleCreateCategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCatName.trim()) return;
    const subcats = newCatSubcategories
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    addCategory({
      name: newCatName,
      slug: newCatSlug.toLowerCase().trim() || newCatName.toLowerCase().replace(/\s+/g, '-'),
      description: newCatDesc || 'General store department',
      iconName: 'ShoppingBag',
      subcategories: subcats.length > 0 ? subcats : ['General Items'],
    });
    setNewCatName('');
    setNewCatSlug('');
    setNewCatDesc('');
    setNewCatSubcategories('');
    setShowAddCat(false);
  };

  const filteredProducts = products.filter((p) => {
    const matchesSearch =
      p.name.toLowerCase().includes(productSearch.toLowerCase()) ||
      p.brand.toLowerCase().includes(productSearch.toLowerCase());
    const matchesCat =
      selectedProductCategory === 'all' || p.categoryId === selectedProductCategory;
    return matchesSearch && matchesCat;
  });

  const filteredOrders = orders.filter((o) => {
    if (orderStatusFilter === 'all') return true;
    return o.status === orderStatusFilter;
  });

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Admin Title Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-zinc-200">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold uppercase tracking-wider text-amber-800 bg-amber-50 px-2 py-0.5 rounded">
              Ram Prasad General Store
            </span>
            <span className="text-xs text-zinc-400">Store Operations & Inventory Console</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-zinc-950 mt-1">
            General Store Admin Panel
          </h1>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsAddProductOpen(true)}
            className="px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white rounded-xl text-xs font-semibold flex items-center gap-1.5 shadow-xs cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Add New Product</span>
          </button>
        </div>
      </div>

      {/* Admin Navigation Pills */}
      <div className="flex items-center gap-1 p-1 bg-zinc-100 rounded-xl my-6 overflow-x-auto max-w-3xl">
        {[
          { key: 'analytics', label: 'Executive Metrics', icon: <BarChart3 className="w-3.5 h-3.5" /> },
          { key: 'orders', label: `Orders (${orders.length})`, icon: <ShoppingCart className="w-3.5 h-3.5" /> },
          { key: 'products', label: `Catalog (${products.length})`, icon: <Package className="w-3.5 h-3.5" /> },
          { key: 'inventory', label: `Inventory Alerts (${lowStockProducts.length})`, icon: <AlertTriangle className="w-3.5 h-3.5" /> },
          { key: 'coupons', label: `Promo Codes (${coupons.length})`, icon: <Tag className="w-3.5 h-3.5" /> },
          { key: 'categories', label: `Aisles (${categories.length})`, icon: <Filter className="w-3.5 h-3.5" /> },
          { key: 'customers', label: 'Customers Directory', icon: <Users className="w-3.5 h-3.5" /> },
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveAdminTab(tab.key as any)}
            className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-lg transition-all whitespace-nowrap cursor-pointer ${
              activeAdminTab === tab.key
                ? 'bg-white text-zinc-950 shadow-xs'
                : 'text-zinc-600 hover:text-zinc-900'
            }`}
          >
            {tab.icon}
            <span>{tab.label}</span>
          </button>
        ))}
      </div>

      {/* TAB 1: ANALYTICS & METRICS */}
      {activeAdminTab === 'analytics' && (
        <div className="space-y-6">
          {/* Executive Stat Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-white p-5 rounded-2xl border border-zinc-200/90 shadow-2xs">
              <div className="text-xs text-zinc-400 font-medium">Net Sales Revenue</div>
              <div className="text-2xl font-bold text-zinc-950 font-mono tabular-nums mt-1">
                {formatPrice(totalRevenue)}
              </div>
              <div className="text-[11px] text-emerald-700 font-medium mt-2 flex items-center gap-1">
                <TrendingUp className="w-3 h-3" />
                <span>+24.8% vs last month</span>
              </div>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-zinc-200/90 shadow-2xs">
              <div className="text-xs text-zinc-400 font-medium">Total Orders Fulfilled</div>
              <div className="text-2xl font-bold text-zinc-950 font-mono tabular-nums mt-1">
                {totalOrdersCount}
              </div>
              <div className="text-[11px] text-zinc-500 mt-2">
                {activeOrders.length} currently active in pipeline
              </div>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-zinc-200/90 shadow-2xs">
              <div className="text-xs text-zinc-400 font-medium">Low Stock Critical Alerts</div>
              <div className="text-2xl font-bold text-amber-600 font-mono tabular-nums mt-1">
                {lowStockProducts.length} items
              </div>
              <div className="text-[11px] text-zinc-500 mt-2">Below safety reorder threshold</div>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-zinc-200/90 shadow-2xs">
              <div className="text-xs text-zinc-400 font-medium">Available Express Couriers</div>
              <div className="text-2xl font-bold text-emerald-800 font-mono tabular-nums mt-1">
                {deliveryPersonnel.length} Riders
              </div>
              <div className="text-[11px] text-zinc-500 mt-2">Average 45-min delivery fulfillment</div>
            </div>
          </div>

          {/* Revenue by Payment Breakdown */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white p-6 rounded-2xl border border-zinc-200/90 shadow-2xs">
              <h3 className="font-semibold text-sm text-zinc-900 mb-4">Payment Channel Breakdown</h3>
              <div className="space-y-3 text-xs">
                {['khalti', 'esewa', 'cod', 'card'].map((method) => {
                  const methodOrders = orders.filter((o) => o.paymentMethod === method);
                  const methodTotal = methodOrders.reduce((sum, o) => sum + o.total, 0);
                  const pct = totalRevenue > 0 ? (methodTotal / totalRevenue) * 100 : 0;
                  return (
                    <div key={method}>
                      <div className="flex justify-between font-medium mb-1">
                        <span className="uppercase">{method}</span>
                        <span className="font-mono tabular-nums">
                          {formatPrice(methodTotal)} ({Math.round(pct)}%)
                        </span>
                      </div>
                      <div className="w-full h-1.5 bg-zinc-100 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-emerald-600 rounded-full"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Quick Operations Actions */}
            <div className="bg-white p-6 rounded-2xl border border-zinc-200/90 shadow-2xs flex flex-col justify-between">
              <div>
                <h3 className="font-semibold text-sm text-zinc-900 mb-2">Central Operations Quick-Jump</h3>
                <p className="text-xs text-zinc-500 leading-relaxed mb-4">
                  Manage orders in progress, assign nearest delivery riders, or restock mountain harvests.
                </p>
                <div className="space-y-2">
                  <button
                    onClick={() => setActiveAdminTab('orders')}
                    className="w-full p-2.5 bg-zinc-50 hover:bg-zinc-100 rounded-xl border border-zinc-200 text-xs font-semibold text-zinc-800 flex items-center justify-between"
                  >
                    <span>View {activeOrders.length} Pending Orders for Dispatch</span>
                    <span>→</span>
                  </button>
                  <button
                    onClick={() => setActiveAdminTab('inventory')}
                    className="w-full p-2.5 bg-amber-50 hover:bg-amber-100/80 rounded-xl border border-amber-200 text-xs font-semibold text-amber-900 flex items-center justify-between"
                  >
                    <span>Audit {lowStockProducts.length} Low-Stock Groceries</span>
                    <span>→</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: ORDERS MANAGEMENT */}
      {activeAdminTab === 'orders' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-zinc-100">
            <h3 className="font-semibold text-sm text-zinc-900">
              Customer Orders Management ({filteredOrders.length})
            </h3>

            {/* Status Filter */}
            <div className="flex items-center gap-2 text-xs">
              <span className="text-zinc-500">Filter Status:</span>
              <select
                value={orderStatusFilter}
                onChange={(e) => setOrderStatusFilter(e.target.value)}
                className="p-1.5 rounded-lg border border-zinc-300 text-xs bg-white font-medium"
              >
                <option value="all">All Orders</option>
                <option value="placed">Placed (New)</option>
                <option value="confirmed">Confirmed</option>
                <option value="packing">Packing</option>
                <option value="out_for_delivery">Out for Delivery</option>
                <option value="delivered">Delivered</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>
          </div>

          <div className="divide-y divide-zinc-100 mt-4">
            {filteredOrders.length === 0 ? (
              <div className="py-12 text-center text-xs text-zinc-400">No orders in this status.</div>
            ) : (
              filteredOrders.map((ord) => (
                <div key={ord.id} className="py-4 space-y-3">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-zinc-900">#{ord.orderNumber}</span>
                        <span className="text-xs text-zinc-500">· {ord.customerName} ({ord.customerPhone})</span>
                      </div>
                      <div className="text-xs text-zinc-500 mt-0.5">
                        Address: {ord.deliveryAddress.street}, {ord.deliveryAddress.city}
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <div className="text-right">
                        <div className="font-bold text-sm text-zinc-950 font-mono tabular-nums">
                          {formatPrice(ord.total)}
                        </div>
                        <div className="text-[11px] text-zinc-400 uppercase">
                          {ord.paymentMethod} ({ord.paymentStatus})
                        </div>
                      </div>

                      {/* Advance Status Dropdown */}
                      <select
                        value={ord.status}
                        onChange={(e) => updateOrderStatus(ord.id, e.target.value as OrderStatus)}
                        className="text-xs font-semibold p-1.5 rounded-lg border border-zinc-300 bg-zinc-50"
                      >
                        <option value="placed">Placed</option>
                        <option value="confirmed">Confirmed</option>
                        <option value="packing">Packing</option>
                        <option value="out_for_delivery">Out for Delivery</option>
                        <option value="delivered">Delivered</option>
                        <option value="cancelled">Cancelled</option>
                      </select>
                    </div>
                  </div>

                  {/* Rider Assignment Cluster */}
                  <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100 flex flex-wrap items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2">
                      <Truck className="w-3.5 h-3.5 text-zinc-500" />
                      <span className="text-zinc-600">Assigned Courier:</span>
                      <span className="font-bold text-zinc-900">
                        {ord.deliveryPersonName || 'Unassigned'}
                      </span>
                    </div>

                    <div className="flex items-center gap-2">
                      <span className="text-zinc-500">Assign Rider:</span>
                      <select
                        defaultValue=""
                        onChange={(e) => {
                          if (e.target.value) assignDeliveryPerson(ord.id, e.target.value);
                        }}
                        className="text-xs p-1 rounded-md border border-zinc-300 bg-white"
                      >
                        <option value="">Choose Rider...</option>
                        {deliveryPersonnel.map((r) => (
                          <option key={r.id} value={r.id}>
                            {r.name} ({r.vehicle})
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* TAB 3: PRODUCTS MANAGEMENT */}
      {activeAdminTab === 'products' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-zinc-100">
            <div className="flex items-center gap-3">
              <input
                type="text"
                placeholder="Search products..."
                value={productSearch}
                onChange={(e) => setProductSearch(e.target.value)}
                className="text-xs p-2 rounded-lg border border-zinc-300 w-56"
              />
              <select
                value={selectedProductCategory}
                onChange={(e) => setSelectedProductCategory(e.target.value)}
                className="text-xs p-2 rounded-lg border border-zinc-300 bg-white"
              >
                <option value="all">All Aisles</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.slug}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            <button
              onClick={() => setIsAddProductOpen(true)}
              className="px-3.5 py-1.5 bg-emerald-700 text-white rounded-lg text-xs font-semibold flex items-center gap-1 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add New Item</span>
            </button>
          </div>

          {/* Table */}
          <div className="overflow-x-auto mt-4">
            <table className="w-full text-left text-xs">
              <thead className="bg-zinc-50 text-zinc-500 uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="p-3">Product</th>
                  <th className="p-3">Price</th>
                  <th className="p-3">Packaging Unit</th>
                  <th className="p-3">Current Stock</th>
                  <th className="p-3">Organic</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {filteredProducts.map((p) => (
                  <tr key={p.id} className="hover:bg-zinc-50/50">
                    <td className="p-3 flex items-center gap-2.5">
                      <img src={p.image} alt={p.name} className="w-8 h-8 rounded object-cover" />
                      <div>
                        <div className="font-semibold text-zinc-900 line-clamp-1">{p.name}</div>
                        <div className="text-[10px] text-zinc-400">{p.brand}</div>
                      </div>
                    </td>
                    <td className="p-3 font-mono font-bold text-zinc-900 tabular-nums">
                      {formatPrice(p.price)}
                    </td>
                    <td className="p-3 text-zinc-600">{p.unit}</td>
                    <td className="p-3">
                      <span
                        className={`font-semibold tabular-nums ${
                          p.stock <= p.minStockAlert ? 'text-amber-600' : 'text-zinc-900'
                        }`}
                      >
                        {p.stock} units
                      </span>
                    </td>
                    <td className="p-3">
                      {p.isOrganic ? (
                        <span className="text-emerald-700 font-bold">Yes</span>
                      ) : (
                        <span className="text-zinc-400">No</span>
                      )}
                    </td>
                    <td className="p-3 text-right space-x-2">
                      <button
                        onClick={() => {
                          const newPrice = prompt(`Update price for ${p.name} (NPR):`, String(p.price));
                          if (newPrice && !isNaN(Number(newPrice))) {
                            updateProduct({ ...p, price: Number(newPrice) });
                          }
                        }}
                        className="text-zinc-600 hover:text-emerald-700"
                        title="Edit price"
                      >
                        <Edit2 className="w-3.5 h-3.5 inline" />
                      </button>
                      <button
                        onClick={() => {
                          if (confirm(`Delete ${p.name}?`)) {
                            deleteProduct(p.id);
                          }
                        }}
                        className="text-zinc-400 hover:text-rose-600"
                        title="Delete product"
                      >
                        <Trash2 className="w-3.5 h-3.5 inline" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: INVENTORY ALERTS */}
      {activeAdminTab === 'inventory' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <div className="pb-4 border-b border-zinc-100">
            <h3 className="font-semibold text-sm text-zinc-900">
              Low Stock Reorder Audits ({lowStockProducts.length} items flagged)
            </h3>
            <p className="text-xs text-zinc-500 mt-0.5">
              Items at or below minimum threshold alert. Use 1-click restock to replenish buffer inventory.
            </p>
          </div>

          <div className="divide-y divide-zinc-100 mt-4">
            {lowStockProducts.length === 0 ? (
              <div className="py-12 text-center text-xs text-emerald-800">
                All items in warehouse have healthy stock buffers!
              </div>
            ) : (
              lowStockProducts.map((p) => (
                <div key={p.id} className="py-3 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-3">
                    <img src={p.image} alt={p.name} className="w-10 h-10 rounded-lg object-cover" />
                    <div>
                      <h4 className="font-semibold text-zinc-900">{p.name}</h4>
                      <div className="text-zinc-400 text-[11px] mt-0.5">
                        Alert Threshold: {p.minStockAlert} units · Current: <span className="text-amber-600 font-bold">{p.stock} units</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => restockProduct(p.id, 20)}
                      className="px-3 py-1.5 bg-emerald-50 text-emerald-800 border border-emerald-200 rounded-lg font-semibold hover:bg-emerald-100 transition-colors"
                    >
                      +20 Units
                    </button>
                    <button
                      onClick={() => restockProduct(p.id, 50)}
                      className="px-3 py-1.5 bg-zinc-900 text-white rounded-lg font-semibold hover:bg-zinc-800 transition-colors"
                    >
                      +50 Units
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* TAB 5: PROMO COUPONS */}
      {activeAdminTab === 'coupons' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <div className="flex items-center justify-between pb-4 border-b border-zinc-100">
            <h3 className="font-semibold text-sm text-zinc-900">Promotional Vouchers & Coupons</h3>
            <button
              onClick={() => setShowAddCoupon(!showAddCoupon)}
              className="px-3.5 py-1.5 bg-emerald-700 text-white rounded-lg text-xs font-semibold flex items-center gap-1 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Create Coupon</span>
            </button>
          </div>

          {showAddCoupon && (
            <form onSubmit={handleCreateCoupon} className="bg-zinc-50 p-4 rounded-xl border border-zinc-200 my-4 space-y-3">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Coupon Code</label>
                  <input
                    type="text"
                    placeholder="e.g. MONSOON25"
                    value={newCouponCode}
                    onChange={(e) => setNewCouponCode(e.target.value)}
                    className="w-full text-xs uppercase p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Discount %</label>
                  <input
                    type="number"
                    value={newCouponPercent}
                    onChange={(e) => setNewCouponPercent(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Max Discount (NPR)</label>
                  <input
                    type="number"
                    value={newCouponMax}
                    onChange={(e) => setNewCouponMax(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddCoupon(false)}
                  className="px-3 py-1.5 text-xs text-zinc-600 bg-zinc-200 rounded-lg"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 text-xs font-semibold text-white bg-emerald-700 rounded-lg"
                >
                  Save Coupon
                </button>
              </div>
            </form>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-4">
            {coupons.map((c) => (
              <div key={c.code} className="p-4 rounded-xl border border-zinc-200 bg-zinc-50/50 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-base text-zinc-900 tracking-wider">
                      {c.code}
                    </span>
                    <button
                      onClick={() => toggleCoupon(c.code)}
                      className={`text-[10px] font-semibold px-2 py-0.5 rounded ${
                        c.active ? 'bg-emerald-100 text-emerald-800' : 'bg-zinc-200 text-zinc-600'
                      }`}
                    >
                      {c.active ? 'Active' : 'Inactive'}
                    </button>
                  </div>
                  <p className="text-xs text-zinc-600 mt-1.5">{c.description}</p>
                  <div className="text-[11px] text-zinc-400 mt-2">
                    Min Basket: Rs. {c.minOrderAmount} · Max Cap: Rs. {c.maxDiscount}
                  </div>
                </div>

                <div className="pt-3 mt-3 border-t border-zinc-200 text-xs text-zinc-500 flex justify-between">
                  <span>Redeemed: {c.usageCount} times</span>
                  <span>Expires: {c.expiryDate}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 6: CATEGORIES */}
      {activeAdminTab === 'categories' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <div className="flex items-center justify-between pb-4 border-b border-zinc-100">
            <h3 className="font-semibold text-sm text-zinc-900">Fresh Aisles & Departments</h3>
            <button
              onClick={() => setShowAddCat(!showAddCat)}
              className="px-3.5 py-1.5 bg-emerald-700 text-white rounded-lg text-xs font-semibold flex items-center gap-1 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add Department</span>
            </button>
          </div>

          {showAddCat && (
            <form onSubmit={handleCreateCategory} className="bg-zinc-50 p-4 rounded-xl border border-zinc-200 my-4 space-y-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Aisle Name</label>
                  <input
                    type="text"
                    placeholder="e.g. Organic Cold Drinks"
                    value={newCatName}
                    onChange={(e) => setNewCatName(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Slug</label>
                  <input
                    type="text"
                    placeholder="e.g. cold-drinks"
                    value={newCatSlug}
                    onChange={(e) => setNewCatSlug(e.target.value)}
                    className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Description</label>
                <input
                  type="text"
                  placeholder="Department details"
                  value={newCatDesc}
                  onChange={(e) => setNewCatDesc(e.target.value)}
                  className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Subcategories (comma-separated)</label>
                <input
                  type="text"
                  placeholder="e.g. Rice & Grains, Pulses, Cooking Oil, Spices"
                  value={newCatSubcategories}
                  onChange={(e) => setNewCatSubcategories(e.target.value)}
                  className="w-full text-xs p-2 rounded-lg border border-zinc-300"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddCat(false)}
                  className="px-3 py-1.5 text-xs text-zinc-600 bg-zinc-200 rounded-lg"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 text-xs font-semibold text-white bg-emerald-700 rounded-lg"
                >
                  Save Department
                </button>
              </div>
            </form>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-4">
            {categories.map((c) => (
              <div key={c.id} className="p-4 rounded-xl border border-zinc-200 bg-zinc-50/50">
                <h4 className="font-semibold text-sm text-zinc-900">{c.name}</h4>
                <div className="text-[11px] text-zinc-400 font-mono mt-0.5">slug: {c.slug}</div>
                <p className="text-xs text-zinc-600 mt-2 line-clamp-2">{c.description}</p>
                <div className="text-xs text-emerald-800 font-medium mt-3">
                  {products.filter((p) => p.categoryId === c.slug).length} active products
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 7: CUSTOMERS */}
      {activeAdminTab === 'customers' && (
        <div className="bg-white rounded-2xl border border-zinc-200/90 p-6 shadow-2xs">
          <h3 className="font-semibold text-sm text-zinc-900 pb-4 border-b border-zinc-100">
            Registered Customer Directory
          </h3>

          <div className="divide-y divide-zinc-100 mt-3">
            {[
              { name: 'Guest Customer', email: 'customer@example.com', phone: '+977 9800000000', orders: orders.length, city: 'Lalitpur' },
              { name: 'Priya Sharma', email: 'priya.s@gmail.com', phone: '+977 9801122334', orders: 4, city: 'Kathmandu' },
              { name: 'Anil Maharjan', email: 'anil.m@outlook.com', phone: '+977 9812998877', orders: 2, city: 'Bhaktapur' },
              { name: 'Kavita Joshi', email: 'kavita.j@gmail.com', phone: '+977 9849001122', orders: 5, city: 'Patan' },
            ].map((cust, i) => (
              <div key={i} className="py-3.5 flex items-center justify-between text-xs">
                <div>
                  <div className="font-semibold text-zinc-900">{cust.name}</div>
                  <div className="text-zinc-500">{cust.email} · {cust.phone}</div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-zinc-900">{cust.orders} lifetime orders</div>
                  <div className="text-zinc-400">{cust.city} Valley</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ADD PRODUCT MODAL */}
      {isAddProductOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-xs">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl border border-zinc-200 max-h-[90vh] overflow-y-auto">
            <h3 className="font-display font-bold text-lg text-zinc-900 mb-4">
              Add New General Store Product
            </h3>

            <form onSubmit={handleCreateProduct} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-zinc-700 font-semibold mb-1">Product Name *</label>
                <input
                  type="text"
                  placeholder="e.g. Classmate Notebook / Surf Excel / Philips 12W LED Bulb"
                  value={newProdName}
                  onChange={(e) => setNewProdName(e.target.value)}
                  className="w-full p-2 rounded-lg border border-zinc-300 focus:outline-amber-600"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Department / Category</label>
                  <select
                    value={newProdCategory}
                    onChange={(e) => {
                      setNewProdCategory(e.target.value);
                      const catObj = categories.find((c) => c.slug === e.target.value);
                      if (catObj && catObj.subcategories && catObj.subcategories.length > 0) {
                        setNewProdSubcategory(catObj.subcategories[0]);
                      }
                    }}
                    className="w-full p-2 rounded-lg border border-zinc-300 bg-white"
                  >
                    {categories.map((c) => (
                      <option key={c.id} value={c.slug}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Subcategory</label>
                  <input
                    type="text"
                    placeholder="e.g. Notebooks, Detergents, Oral Care"
                    value={newProdSubcategory}
                    onChange={(e) => setNewProdSubcategory(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Brand Name</label>
                  <input
                    type="text"
                    placeholder="e.g. Classmate, Philips"
                    value={newProdBrand}
                    onChange={(e) => setNewProdBrand(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">SKU</label>
                  <input
                    type="text"
                    placeholder="Auto-generated if empty"
                    value={newProdSku}
                    onChange={(e) => setNewProdSku(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Barcode</label>
                  <input
                    type="text"
                    placeholder="e.g. 8901030010"
                    value={newProdBarcode}
                    onChange={(e) => setNewProdBarcode(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300 font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Price (NPR) *</label>
                  <input
                    type="number"
                    value={newProdPrice}
                    onChange={(e) => setNewProdPrice(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Unit / Size *</label>
                  <input
                    type="text"
                    placeholder="1 piece, 1 pack, 100g, 1kg"
                    value={newProdUnit}
                    onChange={(e) => setNewProdUnit(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Stock Quantity *</label>
                  <input
                    type="number"
                    value={newProdStock}
                    onChange={(e) => setNewProdStock(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Specifications (Electronics / Tools)</label>
                  <input
                    type="text"
                    placeholder="e.g. 12W B22 Cool White 6500K"
                    value={newProdSpecs}
                    onChange={(e) => setNewProdSpecs(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Warranty Details</label>
                  <input
                    type="text"
                    placeholder="e.g. 1 Year Replacement Warranty"
                    value={newProdWarranty}
                    onChange={(e) => setNewProdWarranty(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Expiry / Best Before</label>
                  <input
                    type="date"
                    value={newProdExpiry}
                    onChange={(e) => setNewProdExpiry(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Origin / Manufacturer</label>
                  <input
                    type="text"
                    placeholder="e.g. Nepal / Authorized Distributor"
                    value={newProdOrigin}
                    onChange={(e) => setNewProdOrigin(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Dimensions / Size</label>
                  <input
                    type="text"
                    placeholder="e.g. A4, Medium, 1000ml"
                    value={newProdSize}
                    onChange={(e) => setNewProdSize(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Color / Variant</label>
                  <input
                    type="text"
                    placeholder="e.g. Blue, Black, White"
                    value={newProdColor}
                    onChange={(e) => setNewProdColor(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
                <div>
                  <label className="block text-zinc-700 font-semibold mb-1">Material</label>
                  <input
                    type="text"
                    placeholder="e.g. Stainless Steel, Brass"
                    value={newProdMaterial}
                    onChange={(e) => setNewProdMaterial(e.target.value)}
                    className="w-full p-2 rounded-lg border border-zinc-300"
                  />
                </div>
              </div>

              <div>
                <label className="block text-zinc-700 font-semibold mb-1">Product Description</label>
                <textarea
                  rows={2}
                  placeholder="Key features, usage tips, and details..."
                  value={newProdDesc}
                  onChange={(e) => setNewProdDesc(e.target.value)}
                  className="w-full p-2 rounded-lg border border-zinc-300"
                />
              </div>

              <div className="flex justify-end gap-2 pt-3 border-t border-zinc-200">
                <button
                  type="button"
                  onClick={() => setIsAddProductOpen(false)}
                  className="px-4 py-2 text-zinc-600 bg-zinc-100 hover:bg-zinc-200 rounded-lg font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 text-white bg-amber-600 hover:bg-amber-700 rounded-lg font-bold shadow-xs cursor-pointer"
                >
                  Publish Store Product
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
