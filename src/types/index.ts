export type UserRole = 'customer' | 'admin' | 'staff' | 'delivery';

export type Currency = 'NPR' | 'USD';

export interface Category {
  id: string;
  name: string;
  slug: string;
  description: string;
  image?: string;
  iconName: string;
  itemCount: number;
  subcategories?: string[];
}

export interface ProductVariant {
  id: string;
  name: string;
  price: number;
  stock: number;
  sku?: string;
}

export interface Product {
  id: string;
  name: string;
  categoryId: string;
  categoryName?: string;
  subcategory: string;
  brand: string;
  sku: string;
  barcode?: string;
  price: number; // in NPR
  originalPrice?: number;
  discountPercent?: number;
  unit: string; // e.g. "1 piece", "1 pack", "1 box", "1 bottle", "1 tube", "1 packet", "1 pair", "1 set", "1 roll", "1 kg", "500 g", "1 L", "100 ml", "1 meter"
  size?: string;
  color?: string;
  material?: string;
  stock: number;
  minStockAlert: number;
  rating: number;
  reviewCount: number;
  isOrganic?: boolean;
  isFeatured?: boolean;
  isBestSeller?: boolean;
  isNewArrival?: boolean;
  isTodayDeal?: boolean;
  description: string;
  origin?: string;
  specifications?: string;
  warranty?: string;
  ingredients?: string;
  expiryDate?: string;
  variants?: ProductVariant[];
  nutrition?: {
    calories?: string;
    protein?: string;
    carbs?: string;
    fat?: string;
    sodium?: string;
    fiber?: string;
    sugar?: string;
  };
  storageInstructions?: string;
  image: string;
  tags: string[];
}

export interface CartItem {
  productId: string;
  product: Product;
  quantity: number;
  unit: string;
  selectedVariant?: string;
  variantPrice?: number;
}

export interface Address {
  id: string;
  title: 'Home' | 'Work' | 'Other';
  fullName: string;
  phone: string;
  street: string;
  city: string;
  province: string;
  postalCode?: string;
  isDefault?: boolean;
  deliveryInstructions?: string;
}

export type PaymentMethod = 'cod' | 'khalti' | 'esewa' | 'card';

export type PaymentStatus = 'pending' | 'completed' | 'failed' | 'refunded';

export type OrderStatus =
  | 'placed'
  | 'confirmed'
  | 'packing'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled';

export interface DeliveryTimeSlot {
  id: string;
  label: string;
  date: string;
  timeWindow: string;
  fee: number;
}

export interface Order {
  id: string;
  orderNumber: string;
  customerId: string;
  customerName: string;
  customerEmail: string;
  customerPhone: string;
  items: CartItem[];
  subtotal: number;
  deliveryFee: number;
  discount: number;
  tip: number;
  total: number;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  paymentTransactionId?: string;
  deliveryAddress: Address;
  deliveryTimeSlot: DeliveryTimeSlot;
  assignedStaffId?: string;
  assignedDeliveryPersonId?: string;
  deliveryPersonName?: string;
  deliveryPersonPhone?: string;
  deliveryNotes?: string;
  createdAt: string;
  estimatedDeliveryTime: string;
  timeline: {
    status: OrderStatus;
    timestamp: string;
    title: string;
    description: string;
  }[];
}

export interface Review {
  id: string;
  productId: string;
  userName: string;
  userAvatar?: string;
  rating: number;
  comment: string;
  createdAt: string;
  verifiedPurchase: boolean;
}

export interface Coupon {
  code: string;
  description: string;
  discountPercent: number;
  minOrderAmount: number;
  maxDiscount: number;
  active: boolean;
  usageCount: number;
  expiryDate: string;
}

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  type: 'order' | 'promo' | 'system';
  timestamp: string;
  read: boolean;
  orderId?: string;
}

export interface DeliveryPersonnel {
  id: string;
  name: string;
  phone: string;
  rating: number;
  vehicle: string;
  activeDeliveriesCount: number;
  avatar: string;
}
