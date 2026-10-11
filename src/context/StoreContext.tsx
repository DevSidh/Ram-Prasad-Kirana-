import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  Product,
  Category,
  CartItem,
  Order,
  OrderStatus,
  Address,
  Coupon,
  DeliveryTimeSlot,
  DeliveryPersonnel,
  Review,
  NotificationItem,
  UserRole,
  Currency,
  PaymentMethod,
} from '../types';
import {
  INITIAL_PRODUCTS,
  INITIAL_CATEGORIES,
  INITIAL_COUPONS,
  INITIAL_TIME_SLOTS,
  INITIAL_ADDRESSES,
  INITIAL_DELIVERY_PERSONNEL,
  INITIAL_REVIEWS,
  STORE_NAME,
} from '../data/initialData';

interface StoreContextType {
  products: Product[];
  categories: Category[];
  cart: CartItem[];
  wishlist: string[];
  orders: Order[];
  coupons: Coupon[];
  addresses: Address[];
  deliveryPersonnel: DeliveryPersonnel[];
  reviews: Review[];
  notifications: NotificationItem[];
  currency: Currency;
  currentRole: UserRole;
  activePage: string;
  activeOrderId: string | null;
  activeProductModalId: string | null;
  searchQuery: string;
  selectedCategory: string;
  isCartDrawerOpen: boolean;

  // Setters & Navigation
  setCurrency: (c: Currency) => void;
  setCurrentRole: (r: UserRole) => void;
  setActivePage: (p: string) => void;
  setActiveOrderId: (id: string | null) => void;
  setActiveProductModalId: (id: string | null) => void;
  setSearchQuery: (q: string) => void;
  setSelectedCategory: (cat: string) => void;
  setIsCartDrawerOpen: (open: boolean) => void;

  // Cart Helpers
  addToCart: (
    product: Product,
    quantity?: number,
    unit?: string,
    selectedVariant?: string,
    variantPrice?: number
  ) => void;
  removeFromCart: (cartItemKey: string) => void;
  updateQuantity: (cartItemKey: string, quantity: number) => void;
  clearCart: () => void;
  cartSubtotal: number;
  cartCount: number;

  // Wishlist
  toggleWishlist: (productId: string) => void;
  isWishlisted: (productId: string) => boolean;

  // Orders
  createOrder: (orderData: {
    address: Address;
    timeSlot: DeliveryTimeSlot;
    paymentMethod: PaymentMethod;
    couponCode?: string;
    discount: number;
    deliveryFee: number;
    tip: number;
  }) => Order;
  updateOrderStatus: (orderId: string, status: OrderStatus, notes?: string) => void;
  assignDeliveryPerson: (orderId: string, deliveryPersonId: string) => void;
  cancelOrder: (orderId: string, reason?: string) => void;

  // Inventory / Products Admin
  addProduct: (product: Omit<Product, 'id' | 'rating' | 'reviewCount'>) => void;
  updateProduct: (product: Product) => void;
  deleteProduct: (productId: string) => void;
  restockProduct: (productId: string, amount: number) => void;

  // Category Admin
  addCategory: (category: Omit<Category, 'id' | 'itemCount'>) => void;
  updateCategory: (category: Category) => void;

  // Coupon Admin
  addCoupon: (coupon: Coupon) => void;
  toggleCoupon: (code: string) => void;

  // Reviews
  addReview: (productId: string, rating: number, comment: string, userName: string) => void;

  // Notifications
  markNotificationRead: (id: string) => void;
  clearNotifications: () => void;
  unreadNotificationsCount: number;

  // Address
  addAddress: (address: Omit<Address, 'id'>) => void;
  updateAddress: (address: Address) => void;
  deleteAddress: (id: string) => void;
  setDefaultAddress: (id: string) => void;

  // Price formatting
  formatPrice: (amountInNPR: number) => string;

  // Reset
  resetDemoData: () => void;
}

const StoreContext = createContext<StoreContextType | undefined>(undefined);

const LOCAL_STORAGE_PREFIX = 'ramprasad_store_v1_';

function getStored<T>(key: string, fallback: T): T {
  try {
    const item = localStorage.getItem(LOCAL_STORAGE_PREFIX + key);
    return item ? JSON.parse(item) : fallback;
  } catch {
    return fallback;
  }
}

function setStored<T>(key: string, value: T): void {
  try {
    localStorage.setItem(LOCAL_STORAGE_PREFIX + key, JSON.stringify(value));
  } catch (e) {
    console.error('Storage error', e);
  }
}

export const StoreProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [products, setProducts] = useState<Product[]>(() => getStored('products', INITIAL_PRODUCTS));
  const [categories, setCategories] = useState<Category[]>(() => getStored('categories', INITIAL_CATEGORIES));
  const [cart, setCart] = useState<CartItem[]>(() => getStored('cart', []));
  const [wishlist, setWishlist] = useState<string[]>(() => getStored('wishlist', ['prod-rice-01', 'prod-bulb-21']));
  const [coupons, setCoupons] = useState<Coupon[]>(() => getStored('coupons', INITIAL_COUPONS));
  const [addresses, setAddresses] = useState<Address[]>(() => getStored('addresses', INITIAL_ADDRESSES));
  const [deliveryPersonnel] = useState<DeliveryPersonnel[]>(INITIAL_DELIVERY_PERSONNEL);
  const [reviews, setReviews] = useState<Review[]>(() => getStored('reviews', INITIAL_REVIEWS));

  // Default sample initial order for testing order tracker right away
  const sampleInitialOrder: Order = {
    id: 'ord-101',
    orderNumber: 'RPG-92418',
    customerId: 'cust-1',
    customerName: 'Guest Customer',
    customerEmail: 'customer@example.com',
    customerPhone: '+977 9841234567',
    items: [
      {
        productId: 'prod-rice-01',
        product: INITIAL_PRODUCTS[0],
        quantity: 1,
        unit: '5 kg bag',
      },
      {
        productId: 'prod-bulb-21',
        product: INITIAL_PRODUCTS[20],
        quantity: 2,
        unit: '1 piece',
      },
      {
        productId: 'prod-surf-11',
        product: INITIAL_PRODUCTS[10],
        quantity: 1,
        unit: '1 kg pack',
      },
      {
        productId: 'prod-notebook-15',
        product: INITIAL_PRODUCTS[14],
        quantity: 3,
        unit: '1 piece (140 pages)',
        selectedVariant: '140 Pages',
        variantPrice: 120,
      },
    ],
    subtotal: 2375,
    deliveryFee: 40,
    discount: 237,
    tip: 50,
    total: 2228,
    status: 'out_for_delivery',
    paymentMethod: 'khalti',
    paymentStatus: 'completed',
    paymentTransactionId: 'KHLT-893128472',
    deliveryAddress: INITIAL_ADDRESSES[0],
    deliveryTimeSlot: INITIAL_TIME_SLOTS[0],
    assignedDeliveryPersonId: 'del-1',
    deliveryPersonName: 'Bikram Thapa',
    deliveryPersonPhone: '+977 9812345678',
    createdAt: new Date(Date.now() - 32 * 60 * 1000).toISOString(),
    estimatedDeliveryTime: 'In 10-15 minutes',
    timeline: [
      {
        status: 'placed',
        timestamp: new Date(Date.now() - 32 * 60 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        title: 'Order Placed & Paid',
        description: 'Payment verified via Khalti Digital Wallet.',
      },
      {
        status: 'confirmed',
        timestamp: new Date(Date.now() - 25 * 60 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        title: 'Order Confirmed',
        description: 'Ram Prasad General Store counter approved the order.',
      },
      {
        status: 'packing',
        timestamp: new Date(Date.now() - 15 * 60 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        title: 'Items Packed & Inspected',
        description: 'Carefully sorted and packaged in durable grocery and stationery bags.',
      },
      {
        status: 'out_for_delivery',
        timestamp: new Date(Date.now() - 6 * 60 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        title: 'Out for Express Delivery',
        description: 'Bikram Thapa is on his motorcycle headed towards Jhamsikhel.',
      },
    ],
  };

  const [orders, setOrders] = useState<Order[]>(() => getStored('orders', [sampleInitialOrder]));

  const [notifications, setNotifications] = useState<NotificationItem[]>(() =>
    getStored('notifications', [
      {
        id: 'notif-1',
        title: 'Order Out For Delivery',
        message: 'Order #RPG-92418 has been dispatched with express rider Bikram Thapa.',
        type: 'order',
        timestamp: '6 mins ago',
        read: false,
        orderId: 'ord-101',
      },
      {
        id: 'notif-2',
        title: 'Ram Prasad General Store Offers',
        message: 'Use coupon RAMPRASAD10 to enjoy 10% off on all everyday essentials and stationery.',
        type: 'promo',
        timestamp: '2 hours ago',
        read: false,
      },
    ])
  );

  const [currency, setCurrency] = useState<Currency>('NPR');
  const [currentRole, setCurrentRole] = useState<UserRole>('customer');
  const [activePage, setActivePage] = useState<string>('home');
  const [activeOrderId, setActiveOrderId] = useState<string | null>('ord-101');
  const [activeProductModalId, setActiveProductModalId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [isCartDrawerOpen, setIsCartDrawerOpen] = useState<boolean>(false);

  // Sync to local storage on changes
  useEffect(() => setStored('products', products), [products]);
  useEffect(() => setStored('categories', categories), [categories]);
  useEffect(() => setStored('cart', cart), [cart]);
  useEffect(() => setStored('wishlist', wishlist), [wishlist]);
  useEffect(() => setStored('orders', orders), [orders]);
  useEffect(() => setStored('coupons', coupons), [coupons]);
  useEffect(() => setStored('addresses', addresses), [addresses]);
  useEffect(() => setStored('reviews', reviews), [reviews]);
  useEffect(() => setStored('notifications', notifications), [notifications]);

  // Cart Calculations with variants support
  const cartSubtotal = cart.reduce((sum, item) => {
    const itemPrice = item.variantPrice !== undefined ? item.variantPrice : item.product.price;
    return sum + itemPrice * item.quantity;
  }, 0);

  const cartCount = cart.reduce((sum, item) => sum + item.quantity, 0);

  const formatPrice = (amountInNPR: number): string => {
    if (currency === 'USD') {
      const inUSD = amountInNPR / 135;
      return `$${inUSD.toFixed(2)}`;
    }
    return `Rs. ${amountInNPR.toLocaleString()}`;
  };

  const getCartItemKey = (item: CartItem): string => {
    return item.selectedVariant ? `${item.productId}__${item.selectedVariant}` : item.productId;
  };

  const addToCart = (
    product: Product,
    quantity = 1,
    unit = product.unit,
    selectedVariant?: string,
    variantPrice?: number
  ) => {
    setCart((prev) => {
      const matchIndex = prev.findIndex(
        (item) => item.productId === product.id && item.selectedVariant === selectedVariant
      );

      if (matchIndex >= 0) {
        const next = [...prev];
        next[matchIndex] = {
          ...next[matchIndex],
          quantity: next[matchIndex].quantity + quantity,
        };
        return next;
      }

      return [
        ...prev,
        {
          productId: product.id,
          product,
          quantity,
          unit,
          selectedVariant,
          variantPrice,
        },
      ];
    });
  };

  const removeFromCart = (cartItemKey: string) => {
    setCart((prev) => prev.filter((item) => getCartItemKey(item) !== cartItemKey && item.productId !== cartItemKey));
  };

  const updateQuantity = (cartItemKey: string, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(cartItemKey);
      return;
    }
    setCart((prev) =>
      prev.map((item) => {
        if (getCartItemKey(item) === cartItemKey || item.productId === cartItemKey) {
          return { ...item, quantity };
        }
        return item;
      })
    );
  };

  const clearCart = () => {
    setCart([]);
  };

  // Wishlist
  const toggleWishlist = (productId: string) => {
    setWishlist((prev) =>
      prev.includes(productId) ? prev.filter((id) => id !== productId) : [...prev, productId]
    );
  };

  const isWishlisted = (productId: string) => wishlist.includes(productId);

  // Create Order
  const createOrder = ({
    address,
    timeSlot,
    paymentMethod,
    couponCode,
    discount,
    deliveryFee,
    tip,
  }: {
    address: Address;
    timeSlot: DeliveryTimeSlot;
    paymentMethod: PaymentMethod;
    couponCode?: string;
    discount: number;
    deliveryFee: number;
    tip: number;
  }): Order => {
    const orderNumber = `RPG-${Math.floor(10000 + Math.random() * 90000)}`;
    const newOrderId = `ord-${Date.now()}`;
    const total = Math.max(0, cartSubtotal + deliveryFee - discount + tip);

    const now = new Date();
    const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const newOrder: Order = {
      id: newOrderId,
      orderNumber,
      customerId: 'cust-1',
      customerName: address.fullName,
      customerEmail: 'customer@example.com',
      customerPhone: address.phone,
      items: [...cart],
      subtotal: cartSubtotal,
      deliveryFee,
      discount,
      tip,
      total,
      status: 'placed',
      paymentMethod,
      paymentStatus: paymentMethod === 'cod' ? 'pending' : 'completed',
      paymentTransactionId:
        paymentMethod === 'cod' ? undefined : `${paymentMethod.toUpperCase()}-${Date.now().toString().slice(-8)}`,
      deliveryAddress: address,
      deliveryTimeSlot: timeSlot,
      createdAt: now.toISOString(),
      estimatedDeliveryTime: timeSlot.timeWindow,
      timeline: [
        {
          status: 'placed',
          timestamp: timeString,
          title: 'Order Placed',
          description:
            paymentMethod === 'cod'
              ? 'Cash on Delivery order booked.'
              : `Payment confirmed via ${paymentMethod.toUpperCase()}.`,
        },
      ],
    };

    // Deduct stock for ordered items
    setProducts((prev) =>
      prev.map((p) => {
        const cartItem = cart.find((ci) => ci.productId === p.id);
        if (cartItem) {
          return {
            ...p,
            stock: Math.max(0, p.stock - cartItem.quantity),
          };
        }
        return p;
      })
    );

    // Update coupon usage if applicable
    if (couponCode) {
      setCoupons((prev) =>
        prev.map((c) => (c.code === couponCode ? { ...c, usageCount: c.usageCount + 1 } : c))
      );
    }

    // Add order
    setOrders((prev) => [newOrder, ...prev]);

    // Add notification
    const newNotif: NotificationItem = {
      id: `notif-${Date.now()}`,
      title: 'Order Placed Successfully',
      message: `Your Ram Prasad General Store order ${orderNumber} is confirmed and queued for packing!`,
      type: 'order',
      timestamp: 'Just now',
      read: false,
      orderId: newOrderId,
    };
    setNotifications((prev) => [newNotif, ...prev]);

    // Clear cart
    clearCart();

    // Set active order for live tracking
    setActiveOrderId(newOrderId);

    return newOrder;
  };

  const updateOrderStatus = (orderId: string, status: OrderStatus, notes?: string) => {
    const timeString = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    let title = 'Status Updated';
    let desc = notes || `Order status updated by ${STORE_NAME}.`;

    if (status === 'confirmed') {
      title = 'Order Confirmed';
      desc = `${STORE_NAME} manager confirmed the order. Sent to packing queue.`;
    } else if (status === 'packing') {
      title = 'Packing in Progress';
      desc = 'Store items are being gathered, verified, and safely packed.';
    } else if (status === 'out_for_delivery') {
      title = 'Out for Delivery';
      desc = 'Assigned delivery agent has picked up the package and is en route.';
    } else if (status === 'delivered') {
      title = 'Delivered to Doorstep';
      desc = `Package handed over. Thank you for shopping with ${STORE_NAME}!`;
    } else if (status === 'cancelled') {
      title = 'Order Cancelled';
      desc = notes || 'Order has been cancelled.';
    }

    setOrders((prev) =>
      prev.map((ord) => {
        if (ord.id === orderId) {
          const updatedTimeline = [
            ...ord.timeline,
            { status, timestamp: timeString, title, description: desc },
          ];
          return {
            ...ord,
            status,
            deliveryNotes: notes || ord.deliveryNotes,
            paymentStatus: status === 'delivered' && ord.paymentMethod === 'cod' ? 'completed' : ord.paymentStatus,
            timeline: updatedTimeline,
          };
        }
        return ord;
      })
    );

    // Send notification
    setNotifications((prev) => [
      {
        id: `notif-${Date.now()}`,
        title: title,
        message: desc,
        type: 'order',
        timestamp: 'Just now',
        read: false,
        orderId,
      },
      ...prev,
    ]);
  };

  const assignDeliveryPerson = (orderId: string, deliveryPersonId: string) => {
    const person = deliveryPersonnel.find((p) => p.id === deliveryPersonId);
    if (!person) return;

    setOrders((prev) =>
      prev.map((ord) => {
        if (ord.id === orderId) {
          return {
            ...ord,
            assignedDeliveryPersonId: person.id,
            deliveryPersonName: person.name,
            deliveryPersonPhone: person.phone,
          };
        }
        return ord;
      })
    );

    updateOrderStatus(
      orderId,
      'out_for_delivery',
      `Assigned to rider ${person.name} (${person.vehicle}). Contact: ${person.phone}`
    );
  };

  const cancelOrder = (orderId: string, reason?: string) => {
    updateOrderStatus(orderId, 'cancelled', reason || 'Cancelled by customer.');
  };

  // Admin Product Actions
  const addProduct = (data: Omit<Product, 'id' | 'rating' | 'reviewCount'>) => {
    const newProduct: Product = {
      ...data,
      id: `prod-${Date.now()}`,
      rating: 5.0,
      reviewCount: 1,
    };
    setProducts((prev) => [newProduct, ...prev]);
  };

  const updateProduct = (updated: Product) => {
    setProducts((prev) => prev.map((p) => (p.id === updated.id ? updated : p)));
  };

  const deleteProduct = (productId: string) => {
    setProducts((prev) => prev.filter((p) => p.id !== productId));
  };

  const restockProduct = (productId: string, amount: number) => {
    setProducts((prev) =>
      prev.map((p) => (p.id === productId ? { ...p, stock: p.stock + amount } : p))
    );
  };

  // Admin Category Actions
  const addCategory = (data: Omit<Category, 'id' | 'itemCount'>) => {
    const newCat: Category = {
      ...data,
      id: `cat-${Date.now()}`,
      itemCount: 0,
    };
    setCategories((prev) => [...prev, newCat]);
  };

  const updateCategory = (updated: Category) => {
    setCategories((prev) => prev.map((c) => (c.id === updated.id ? updated : c)));
  };

  // Admin Coupon Actions
  const addCoupon = (coupon: Coupon) => {
    setCoupons((prev) => [coupon, ...prev]);
  };

  const toggleCoupon = (code: string) => {
    setCoupons((prev) =>
      prev.map((c) => (c.code === code ? { ...c, active: !c.active } : c))
    );
  };

  // Review Actions
  const addReview = (productId: string, rating: number, comment: string, userName: string) => {
    const newRev: Review = {
      id: `rev-${Date.now()}`,
      productId,
      userName: userName || 'Verified Customer',
      rating,
      comment,
      createdAt: 'Just now',
      verifiedPurchase: true,
    };
    setReviews((prev) => [newRev, ...prev]);

    setProducts((prev) =>
      prev.map((p) => {
        if (p.id === productId) {
          const newCount = p.reviewCount + 1;
          const newAvg = Number(((p.rating * p.reviewCount + rating) / newCount).toFixed(1));
          return { ...p, rating: newAvg, reviewCount: newCount };
        }
        return p;
      })
    );
  };

  // Notification Actions
  const markNotificationRead = (id: string) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n))
    );
  };

  const clearNotifications = () => {
    setNotifications([]);
  };

  const unreadNotificationsCount = notifications.filter((n) => !n.read).length;

  // Address Actions
  const addAddress = (data: Omit<Address, 'id'>) => {
    const newAddr: Address = {
      ...data,
      id: `addr-${Date.now()}`,
    };
    if (newAddr.isDefault) {
      setAddresses((prev) => [...prev.map((a) => ({ ...a, isDefault: false })), newAddr]);
    } else {
      setAddresses((prev) => [...prev, newAddr]);
    }
  };

  const updateAddress = (updated: Address) => {
    setAddresses((prev) =>
      prev.map((a) => {
        if (a.id === updated.id) return updated;
        if (updated.isDefault) return { ...a, isDefault: false };
        return a;
      })
    );
  };

  const deleteAddress = (id: string) => {
    setAddresses((prev) => prev.filter((a) => a.id !== id));
  };

  const setDefaultAddress = (id: string) => {
    setAddresses((prev) =>
      prev.map((a) => ({ ...a, isDefault: a.id === id }))
    );
  };

  // Reset Demo Data
  const resetDemoData = () => {
    setProducts(INITIAL_PRODUCTS);
    setCategories(INITIAL_CATEGORIES);
    setCoupons(INITIAL_COUPONS);
    setAddresses(INITIAL_ADDRESSES);
    setOrders([sampleInitialOrder]);
    setReviews(INITIAL_REVIEWS);
    setCart([]);
    localStorage.clear();
  };

  return (
    <StoreContext.Provider
      value={{
        products,
        categories,
        cart,
        wishlist,
        orders,
        coupons,
        addresses,
        deliveryPersonnel,
        reviews,
        notifications,
        currency,
        currentRole,
        activePage,
        activeOrderId,
        activeProductModalId,
        searchQuery,
        selectedCategory,
        isCartDrawerOpen,

        setCurrency,
        setCurrentRole,
        setActivePage,
        setActiveOrderId,
        setActiveProductModalId,
        setSearchQuery,
        setSelectedCategory,
        setIsCartDrawerOpen,

        addToCart,
        removeFromCart,
        updateQuantity,
        clearCart,
        cartSubtotal,
        cartCount,

        toggleWishlist,
        isWishlisted,

        createOrder,
        updateOrderStatus,
        assignDeliveryPerson,
        cancelOrder,

        addProduct,
        updateProduct,
        deleteProduct,
        restockProduct,

        addCategory,
        updateCategory,

        addCoupon,
        toggleCoupon,

        addReview,

        markNotificationRead,
        clearNotifications,
        unreadNotificationsCount,

        addAddress,
        updateAddress,
        deleteAddress,
        setDefaultAddress,

        formatPrice,
        resetDemoData,
      }}
    >
      {children}
    </StoreContext.Provider>
  );
};

export const useStore = (): StoreContextType => {
  const context = useContext(StoreContext);
  if (!context) {
    throw new Error('useStore must be used within a StoreProvider');
  }
  return context;
};
