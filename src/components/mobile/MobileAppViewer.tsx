import React, { useState } from 'react';
import { useStore } from '../../context/StoreContext';
import {
  Smartphone,
  Tablet,
  CheckCircle2,
  Terminal,
  FolderTree,
  FileCode,
  Shield,
  Layers,
  ShoppingBag,
  Search,
  Grid,
  User,
  Heart,
  ArrowRight,
  Package,
  Truck,
  RotateCcw,
} from 'lucide-react';
import { HomePage } from '../customer/HomePage';
import { MarketCatalog } from '../customer/MarketCatalog';
import { CheckoutView } from '../customer/CheckoutView';
import { OrderTrackingView } from '../customer/OrderTrackingView';
import { UserAccountView } from '../customer/UserAccountView';
import { DeliveryPortalView } from '../delivery/DeliveryPortalView';

export const MobileAppViewer: React.FC = () => {
  const { cartCount, formatPrice, cartSubtotal, activeOrderId } = useStore();
  const [deviceFrame, setDeviceFrame] = useState<'android' | 'ios'>('android');
  const [currentMobileTab, setCurrentMobileTab] = useState<'home' | 'categories' | 'search' | 'cart' | 'account' | 'delivery'>('home');
  const [selectedFileCode, setSelectedFileCode] = useState<string>('lib/main.dart');

  const flutterFiles: { [path: string]: { label: string; desc: string; preview: string } } = {
    'lib/main.dart': {
      label: 'lib/main.dart',
      desc: 'Flutter App Entry Point with MultiProvider registration',
      preview: `import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(apiService: apiService)),
        ChangeNotifierProvider<ProductProvider>(create: (_) => ProductProvider(apiService: apiService)),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
      ],
      child: const RamPrasadGeneralStoreApp(),
    ),
  );
}`,
    },
    'pubspec.yaml': {
      label: 'pubspec.yaml',
      desc: 'Flutter Dependencies & Material 3 Setup',
      preview: `name: ram_prasad_general_store
description: "Production general store & household essentials delivery mobile application."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  http: ^1.2.0
  shared_preferences: ^2.2.2
  cached_network_image: ^3.3.1
  google_fonts: ^6.1.0
  intl: ^0.19.0`,
    },
    'android/app/build.gradle': {
      label: 'android/app/build.gradle',
      desc: 'Android Native Gradle Configuration (minSdkVersion 26, compileSdkVersion 34)',
      preview: `android {
    namespace "com.ramprasad.general_store"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.ramprasad.general_store"
        minSdkVersion 26
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
        }
    }
}`,
    },
    'backend/prisma/schema.prisma': {
      label: 'backend/prisma/schema.prisma',
      desc: 'PostgreSQL Database Schema with all 28 required models',
      preview: `datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Product {
  id              String   @id @default(uuid())
  sku             String   @unique
  name            String
  price           Decimal  @db.Decimal(10, 2)
  weight          String
  stock           Int
  isOrganic       Boolean  @default(false)
  inventory       Inventory?
  cartItems       CartItem[]
}

model Inventory {
  id            String   @id @default(uuid())
  productId     String   @unique
  totalStock    Int
  reservedStock Int
  version       Int      @default(0) // Optimistic concurrency lock
}`,
    },
    'backend/src/services/inventory.ts': {
      label: 'backend/src/services/inventory.ts',
      desc: 'Atomic Concurrency Protection preventing negative inventory',
      preview: `export class InventoryService {
  async reserveStockForOrder(tx, items, orderId) {
    for (const item of items) {
      // Atomic CAS conditional update prevents simultaneous overselling
      const rows = await tx.$executeRaw\`
        UPDATE "Inventory"
        SET "reservedStock" = "reservedStock" + \${item.quantity}, "version" = "version" + 1
        WHERE "productId" = \${item.productId}
          AND ("totalStock" - "reservedStock") >= \${item.quantity};
      \`;
      if (rows === 0) throw new Error("INSUFFICIENT_STOCK");
    }
  }
}`,
    },
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 my-8">
      {/* Top Banner */}
      <div className="bg-zinc-900 text-white rounded-2xl p-6 mb-8 border border-zinc-800 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-950/80 px-2.5 py-0.5 rounded border border-emerald-800">
              Flutter 3 · Material 3 Mobile App
            </span>
            <span className="text-xs text-zinc-400">Android APK & iOS Bundle Ready</span>
          </div>
          <h1 className="text-xl sm:text-2xl font-bold font-display mt-1">
            Native Mobile App Simulator & Project Architecture
          </h1>
          <p className="text-xs text-zinc-400 mt-1 max-w-xl">
            Complete standalone Flutter mobile codebase generated in <code className="text-emerald-400">/lib</code>, <code className="text-emerald-400">/android</code>, <code className="text-emerald-400">/ios</code>, and <code className="text-emerald-400">/backend</code>.
          </p>
        </div>

        {/* Device Switcher */}
        <div className="flex items-center gap-2 bg-zinc-800/80 p-1 rounded-xl border border-zinc-700">
          <button
            onClick={() => setDeviceFrame('android')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              deviceFrame === 'android' ? 'bg-emerald-600 text-white shadow-xs' : 'text-zinc-400 hover:text-white'
            }`}
          >
            <Smartphone className="w-3.5 h-3.5" />
            <span>Android Phone</span>
          </button>
          <button
            onClick={() => setDeviceFrame('ios')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              deviceFrame === 'ios' ? 'bg-emerald-600 text-white shadow-xs' : 'text-zinc-400 hover:text-white'
            }`}
          >
            <Tablet className="w-3.5 h-3.5" />
            <span>iPhone 15 Pro</span>
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Column: Authentic Mobile Phone Mockup */}
        <div className="lg:col-span-6 flex justify-center">
          <div
            className={`w-[380px] sm:w-[410px] h-[820px] bg-zinc-950 rounded-[48px] p-3 shadow-2xl border-[6px] ${
              deviceFrame === 'ios' ? 'border-zinc-700' : 'border-zinc-800'
            } relative flex flex-col`}
          >
            {/* Speaker & Dynamic Island / Camera Notch */}
            <div className="absolute top-5 left-1/2 -translate-x-1/2 z-30">
              {deviceFrame === 'ios' ? (
                <div className="w-24 h-6 bg-black rounded-full flex items-center justify-center">
                  <div className="w-2.5 h-2.5 rounded-full bg-zinc-900 ml-auto mr-2" />
                </div>
              ) : (
                <div className="w-3 h-3 bg-black rounded-full" />
              )}
            </div>

            {/* Mobile Screen Canvas */}
            <div className="w-full h-full bg-[#FAFAFA] rounded-[38px] overflow-hidden flex flex-col justify-between relative">
              {/* Mobile Status Bar */}
              <div className="h-10 bg-white/95 backdrop-blur-md px-6 flex items-center justify-between text-[11px] font-bold text-zinc-900 border-b border-zinc-100 z-20">
                <span>9:41</span>
                <div className="flex items-center gap-1.5 text-zinc-800">
                  <span>5G</span>
                  <span>100%</span>
                </div>
              </div>

              {/* Scrollable Mobile App Views */}
              <div className="flex-1 overflow-y-auto overflow-x-hidden">
                {currentMobileTab === 'home' && <HomePage />}
                {currentMobileTab === 'categories' && <MarketCatalog />}
                {currentMobileTab === 'search' && <MarketCatalog />}
                {currentMobileTab === 'cart' && <CheckoutView />}
                {currentMobileTab === 'account' && <UserAccountView />}
                {currentMobileTab === 'delivery' && <DeliveryPortalView />}
              </div>

              {/* Material 3 Mobile Bottom Navigation Bar */}
              <div className="bg-white border-t border-zinc-200/90 py-2 px-3 flex items-center justify-around z-20">
                <button
                  onClick={() => setCurrentMobileTab('home')}
                  className={`flex flex-col items-center gap-1 text-[10px] font-semibold cursor-pointer ${
                    currentMobileTab === 'home' ? 'text-emerald-700 font-bold' : 'text-zinc-500 hover:text-zinc-800'
                  }`}
                >
                  <ShoppingBag className="w-4 h-4" />
                  <span>Home</span>
                </button>

                <button
                  onClick={() => setCurrentMobileTab('categories')}
                  className={`flex flex-col items-center gap-1 text-[10px] font-semibold cursor-pointer ${
                    currentMobileTab === 'categories' ? 'text-emerald-700 font-bold' : 'text-zinc-500 hover:text-zinc-800'
                  }`}
                >
                  <Grid className="w-4 h-4" />
                  <span>Aisles</span>
                </button>

                <button
                  onClick={() => setCurrentMobileTab('search')}
                  className={`flex flex-col items-center gap-1 text-[10px] font-semibold cursor-pointer ${
                    currentMobileTab === 'search' ? 'text-emerald-700 font-bold' : 'text-zinc-500 hover:text-zinc-800'
                  }`}
                >
                  <Search className="w-4 h-4" />
                  <span>Search</span>
                </button>

                <button
                  onClick={() => setCurrentMobileTab('cart')}
                  className={`flex flex-col items-center gap-1 text-[10px] font-semibold cursor-pointer relative ${
                    currentMobileTab === 'cart' ? 'text-emerald-700 font-bold' : 'text-zinc-500 hover:text-zinc-800'
                  }`}
                >
                  <div className="relative">
                    <ShoppingBag className="w-4 h-4" />
                    {cartCount > 0 && (
                      <span className="absolute -top-1 -right-2 bg-emerald-600 text-white rounded-full text-[9px] w-3.5 h-3.5 flex items-center justify-center font-bold">
                        {cartCount}
                      </span>
                    )}
                  </div>
                  <span>Cart</span>
                </button>

                <button
                  onClick={() => setCurrentMobileTab('account')}
                  className={`flex flex-col items-center gap-1 text-[10px] font-semibold cursor-pointer ${
                    currentMobileTab === 'account' ? 'text-emerald-700 font-bold' : 'text-zinc-500 hover:text-zinc-800'
                  }`}
                >
                  <User className="w-4 h-4" />
                  <span>Account</span>
                </button>
              </div>

              {/* Bottom Home Indicator Bar */}
              <div className="h-4 bg-white flex items-center justify-center">
                <div className="w-32 h-1 bg-zinc-300 rounded-full" />
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Codebase Inspector & Flutter Build Instructions */}
        <div className="lg:col-span-6 space-y-6">
          {/* Build Terminal Commands */}
          <div className="bg-zinc-950 text-zinc-200 rounded-2xl p-5 border border-zinc-800 font-mono text-xs">
            <div className="flex items-center justify-between pb-3 border-b border-zinc-800 text-[11px] text-zinc-400">
              <span className="flex items-center gap-1.5 text-emerald-400">
                <Terminal className="w-3.5 h-3.5" />
                <span>Flutter Production Build Commands</span>
              </span>
              <span>v3.16+ · Ready</span>
            </div>

            <div className="mt-3 space-y-2 text-zinc-300">
              <div>
                <span className="text-zinc-500"># 1. Fetch dependencies</span>
                <div className="text-emerald-400 select-all">$ flutter pub get</div>
              </div>
              <div>
                <span className="text-zinc-500"># 2. Build standalone Android APK file</span>
                <div className="text-emerald-400 select-all">$ flutter build apk --release</div>
              </div>
              <div>
                <span className="text-zinc-500"># 3. Build Google Play Store AAB Bundle</span>
                <div className="text-emerald-400 select-all">$ flutter build appbundle --release</div>
              </div>
              <div>
                <span className="text-zinc-500"># 4. Run Critical Concurrency Test (Stock = 1 race test)</span>
                <div className="text-emerald-400 select-all">$ npx tsx backend/tests/concurrency.test.ts</div>
              </div>
            </div>
          </div>

          {/* Project File Inspector */}
          <div className="bg-white rounded-2xl border border-zinc-200 p-5 shadow-2xs">
            <div className="flex items-center justify-between pb-3 border-b border-zinc-100">
              <h3 className="font-bold text-xs uppercase tracking-wider text-zinc-800 flex items-center gap-1.5">
                <FileCode className="w-4 h-4 text-emerald-700" />
                <span>Mobile Project File Inspector</span>
              </h3>
            </div>

            {/* File Selector Pills */}
            <div className="flex flex-wrap gap-1.5 my-3">
              {Object.keys(flutterFiles).map((path) => (
                <button
                  key={path}
                  onClick={() => setSelectedFileCode(path)}
                  className={`px-2.5 py-1 text-xs rounded-md font-mono transition-colors cursor-pointer ${
                    selectedFileCode === path
                      ? 'bg-emerald-700 text-white font-bold'
                      : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                  }`}
                >
                  {flutterFiles[path].label}
                </button>
              ))}
            </div>

            <div className="text-xs text-zinc-500 mb-2">
              {flutterFiles[selectedFileCode]?.desc}
            </div>

            {/* Code Snippet Box */}
            <pre className="bg-zinc-900 text-emerald-300 p-4 rounded-xl text-xs font-mono overflow-x-auto max-h-72 border border-zinc-800 leading-relaxed">
              <code>{flutterFiles[selectedFileCode]?.preview}</code>
            </pre>
          </div>

          {/* Architecture Features Checkcard */}
          <div className="bg-white rounded-2xl border border-zinc-200 p-5 shadow-2xs">
            <h3 className="font-bold text-xs uppercase tracking-wider text-zinc-800 pb-3 border-b border-zinc-100 mb-3">
              Guaranteed Mobile Engineering Standards
            </h3>
            <div className="grid grid-cols-2 gap-3 text-xs">
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Material 3 Flutter Theme</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>MultiProvider Architecture</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>PostgreSQL & Prisma Models</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Atomic Concurrency Tests</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>eSewa & Khalti & COD</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-700">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Standalone Android/iOS Build</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
