# Google Maps Integration Architecture

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        CUSTOMER MOBILE APP (Flutter)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Profile → Delivery Addresses → Add/Edit Address                │
│                                      ↓                            │
│                          [Choose a map pin (optional)]           │
│                                      ↓                            │
│    ┌──────────────────────────────────────────────────┐          │
│    │  GoogleMap Widget (google_maps_flutter plugin)   │          │
│    │                                                  │          │
│    │  - Shows interactive map                        │          │
│    │  - Default center: Kathmandu (26.7288, 85.9263)│          │
│    │  - User can tap to place marker                │          │
│    │  - Shows marker at tapped location             │          │
│    │                                                  │          │
│    └──────────────────────────────────────────────────┘          │
│                                      ↓                            │
│                    User taps "Use this location"                 │
│                                      ↓                            │
│    ┌──────────────────────────────────────────────────┐          │
│    │  Geocoding Service (geocoding plugin)           │          │
│    │                                                  │          │
│    │  Input: LatLng (27.6742, 85.3242)              │          │
│    │  ↓                                              │          │
│    │  Calls: Geocoding.placemarkFromCoordinates()  │          │
│    │  ↓                                              │          │
│    │  Output: Placemark                             │          │
│    │    - street: "Pulchowk, Lalitpur"             │          │
│    │    - locality: "Lalitpur"                      │          │
│    │    - administrativeArea: "Bagmati"            │          │
│    │                                                  │          │
│    └──────────────────────────────────────────────────┘          │
│                                      ↓                            │
│           Form fields auto-fill (street, city, province)        │
│           User can edit if needed                                │
│                                      ↓                            │
│                         User taps "Save"                         │
│                                      ↓                            │
│    ┌──────────────────────────────────────────────────┐          │
│    │  API Call: POST /account/addresses              │          │
│    │                                                  │          │
│    │  Request body:                                  │          │
│    │  {                                              │          │
│    │    "title": "Home",                            │          │
│    │    "fullName": "Siddhant Kumar",               │          │
│    │    "phone": "+977-981234567",                  │          │
│    │    "street": "Pulchowk, Lalitpur",           │          │
│    │    "city": "Lalitpur",                         │          │
│    │    "province": "Bagmati",                      │          │
│    │    "landmark": "Near Patan Square (optional)", │          │
│    │    "latitude": 27.6742,                        │          │
│    │    "longitude": 85.3242                        │          │
│    │  }                                              │          │
│    │                                                  │          │
│    └──────────────────────────────────────────────────┘          │
│                          (HTTPS + Auth Token)                     │
│                                                                   │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   │ POST /account/addresses
                   ↓
┌──────────────────────────────────────────────────────────────────┐
│                  BACKEND API SERVER (Node.js)                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Express Route: router.post('/addresses')                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────┐          │
│  │ 1. Extract authenticated user ID from token      │          │
│  │ 2. Validate input (zod schema)                   │          │
│  │ 3. Check if first address (should be default)   │          │
│  │ 4. Prepare data for database:                   │          │
│  │    - addressLine1 ← street                       │          │
│  │    - addressLine2 ← landmark                     │          │
│  │    - city ← city                                 │          │
│  │    - province ← province                         │          │
│  │    - latitude ← latitude                         │          │
│  │    - longitude ← longitude                       │          │
│  │ 5. Create transaction (atomic):                 │          │
│  │    - If isDefault, unset other addresses        │          │
│  │    - Insert new address                         │          │
│  │ 6. Return response with coordinates             │          │
│  │                                                  │          │
│  └────────────────────────────────────────────────────┘          │
│                                                                   │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   │ INSERT INTO Address (...)
                   ↓
┌──────────────────────────────────────────────────────────────────┐
│                  DATABASE (CockroachDB)                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Table: Address                                                  │
│  ┌────────────────────────────────────────────────────┐          │
│  │ id (CUID)      → clx7a8b9c0d1e2f3g4h5i6j7k8l    │          │
│  │ userId         → clx1234567890abcdefghijk       │          │
│  │ label          → "Home"                          │          │
│  │ fullName       → "Siddhant Kumar"               │          │
│  │ phone          → "+977-981234567"               │          │
│  │ addressLine1   → "Pulchowk, Lalitpur"         │          │
│  │ addressLine2   → "Near Patan Square"            │          │
│  │ city           → "Lalitpur"                      │          │
│  │ province       → "Bagmati"                       │          │
│  │ latitude       → 27.6742 ◄─ STORED COORDINATE   │          │
│  │ longitude      → 85.3242 ◄─ STORED COORDINATE   │          │
│  │ isDefault      → true                            │          │
│  │ createdAt      → 2025-01-15T10:30:00Z          │          │
│  │ updatedAt      → 2025-01-15T10:30:00Z          │          │
│  │                                                  │          │
│  │ INDEX: userId (fast per-customer lookups)       │          │
│  └────────────────────────────────────────────────────┘          │
│                                                                   │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   │ Data persisted
                   ↓
                   ✓ Ready for delivery assignment

```

---

## Data Flow During Delivery Assignment

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN PANEL (Web Browser)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Orders → Select Order → Assign to Delivery Person             │
│                                      ↓                            │
│  POST /admin/deliveries/assign                                  │
│  Payload:                                                        │
│  {                                                               │
│    "orderId": "...",                                            │
│    "deliveryPersonId": "..."                                   │
│  }                                                               │
│                                                                   │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────────┐
│                  BACKEND API SERVER (Node.js)                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Delivery assignment created                                     │
│  - Links Order to Delivery Person                               │
│  - Sets status to "ASSIGNED"                                    │
│                                                                   │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────────┐
│                DELIVERY STAFF APP (Flutter Mobile)                │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Delivery Person's Dashboard → View Assignments                 │
│                                      ↓                            │
│  GET /delivery/assignments                                       │
│                                      ↓                            │
│  Response includes:                                              │
│  {                                                               │
│    "assignments": [                                             │
│      {                                                           │
│        "id": "delivery-123",                                    │
│        "order": {                                               │
│          "id": "order-456",                                    │
│          "orderNumber": "ORD-2025-001",                        │
│          "address": "Pulchowk, Lalitpur",                     │
│          "latitude": 27.6742,                ◄─ COORDINATES    │
│          "longitude": 85.3242,               ◄─ FROM DATABASE  │
│          "customerName": "Siddhant Kumar",                     │
│          "customerPhone": "+977-981234567",                   │
│          "items": [...]                                        │
│        }                                                        │
│      }                                                           │
│    ]                                                             │
│  }                                                               │
│                                      ↓                            │
│  ┌──────────────────────────────────────────────┐               │
│  │  Delivery Details Screen                     │               │
│  │                                              │               │
│  │  Order: ORD-2025-001                        │               │
│  │  Customer: Siddhant Kumar                   │               │
│  │  Phone: +977-981234567                      │               │
│  │  Address: Pulchowk, Lalitpur                │               │
│  │                                              │               │
│  │  ┌─────────────────────────────┐            │               │
│  │  │  [Show on Map]              │            │               │
│  │  │  Coordinates: 27.6742, 85.3242         │               │
│  │  │  ▼                                       │               │
│  │  │  Opens external map app                 │               │
│  │  │  (Google Maps, Apple Maps, etc.)       │               │
│  │  │                                         │               │
│  │  │  Navigation starts → Delivery person   │               │
│  │  │  can navigate to customer               │               │
│  │  │                                         │               │
│  │  └─────────────────────────────┘            │               │
│  │                                              │               │
│  │  Status: Assigned → Accepted → Picked Up   │               │
│  │          → Out for Delivery → Delivered    │               │
│  │                                              │               │
│  └──────────────────────────────────────────────┘               │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

```

---

## Component Interactions

```
┌────────────────────────────────────────────────────────────────┐
│                    Address Flow Components                       │
└────────────────────────────────────────────────────────────────┘

1. ADDRESS_BOOK_SCREEN (Customer)
   ├─ View saved addresses
   ├─ Click "Add Address"
   │  └─→ _AddressFormDialog opens
   │      ├─ Manual entry fields (name, phone, street, city, etc.)
   │      ├─ [Choose a map pin (optional)] button
   │      │  └─→ Calls _chooseMapLocation()
   │      │      └─→ Navigates to AddressMapPicker
   │      │
   │      └─ AddressMapPicker returns PickedAddressLocation
   │         {
   │           latitude: 27.6742,
   │           longitude: 85.3242,
   │           street: "...",
   │           city: "...",
   │           province: "..."
   │         }
   │         └─→ Updates TextEditingControllers
   │            └─→ User reviews/edits
   │               └─→ Submits POST /account/addresses
   │                  └─→ Backend stores in DB
   │                     └─→ DONE ✓


2. ADDRESS_MAP_PICKER (Modal)
   ├─ GoogleMap widget (requires GOOGLE_MAPS_CONFIGURED=true)
   ├─ User taps on map → setState(() => _selectedPosition = position)
   ├─ Marker updates to new position
   ├─ User taps "Use this location"
   │  └─→ Geocoding.placemarkFromCoordinates()
   │      └─→ Gets Placemark object
   │         └─→ Extracts street, city, province
   │            └─→ Navigator.pop() with PickedAddressLocation
   │               └─→ Returns to form dialog


3. BACKEND ADDRESS ROUTES (Node.js)
   ├─ POST /account/addresses
   │  ├─ Validate input
   │  ├─ Check if first address (set as default)
   │  ├─ Create database record
   │  └─→ Return addressResponse { latitude, longitude, ... }
   │
   ├─ GET /account/addresses
   │  ├─ Query all addresses for user
   │  └─→ Return array of addressResponse objects
   │
   ├─ PATCH /account/addresses/:id
   │  ├─ Validate input (partial update)
   │  ├─ Update database record
   │  └─→ Return updated addressResponse
   │
   └─ DELETE /account/addresses/:id
      ├─ Delete record
      └─→ Confirm deletion


4. DELIVERY ASSIGNMENT ROUTE (Node.js)
   ├─ GET /delivery/assignments
   │  ├─ Query deliveries for delivery person
   │  ├─ For each delivery:
   │  │  └─→ Include order.address with latitude, longitude
   │  │     (from JOIN with Address table)
   │  └─→ Return assignments with full coordinates
   │
   └─→ Delivery staff app displays on map


5. DATABASE PERSISTENCE (CockroachDB)
   └─ Address table stores:
      ├─ addressLine1 (street)
      ├─ city
      ├─ province
      ├─ latitude ◄─ From map picker
      ├─ longitude ◄─ From map picker
      └─ Additional fields (landmark, instructions, etc.)

```

---

## Configuration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  Developer Configuration                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│ 1. Get API Key from Google Cloud Console                         │
│    └─→ AIzaSyD1234567890abcdefghijklmnop                        │
│                                                                   │
│ 2. Configure Android                                            │
│    └─→ android/local.properties                                 │
│        MAPS_API_KEY=AIzaSyD1234567890abcdefghijklmnop          │
│        └─→ Gradle reads at build time                          │
│            └─→ Injects into AndroidManifest.xml via ${MAPS_API_KEY}
│                └─→ Android app loads API key                   │
│                                                                   │
│ 3. Configure iOS                                                │
│    └─→ ios/Runner/Info.plist                                   │
│        <key>com.google.ios.maps</key>                          │
│        <string>AIzaSyD1234567890abcdefghijklmnop</string>       │
│        └─→ iOS app reads at launch                             │
│            └─→ Initializes Google Maps                         │
│                                                                   │
│ 4. Build with Flag                                              │
│    └─→ flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true   │
│        └─→ Sets const _googleMapsConfigured = true             │
│            └─→ AddressMapPicker shows interactive map          │
│                (vs. fallback "map unavailable" screen)         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

```

---

## Why This Architecture?

✓ **Separation of Concerns**
  - Flutter handles UI and user interaction
  - Backend validates and persists data
  - Database is single source of truth

✓ **Scalability**
  - Coordinates stored once, used many times
  - Backend can add distance-based queries later
  - Delivery staff can use external map apps

✓ **Reliability**
  - Fallback to manual address entry if maps unavailable
  - Geocoding is optional (address can be typed manually)
  - Database transactions ensure data consistency

✓ **Security**
  - API key restricted to your app package/bundle ID
  - Google Cloud restricts to your APIs only
  - Backend validates all coordinates before storing

✓ **User Experience**
  - Map picker is intuitive (tap to place marker)
  - Auto-fill reduces manual data entry
  - Users can edit auto-filled values if needed

---

## Environment Variables & Configuration

No environment variables needed! All configuration is:
1. **Android**: `android/local.properties` (MAPS_API_KEY)
2. **iOS**: `ios/Runner/Info.plist` (com.google.ios.maps key)
3. **Flutter**: `--dart-define=GOOGLE_MAPS_CONFIGURED=true` flag at build time
4. **Backend**: No changes (already supports latitude/longitude in existing endpoints)
5. **Database**: No schema migrations (existing Address table ready)
