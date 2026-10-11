# Google Maps Integration & Database Schema Summary

## Current Status ✅

Your FreshHarvest app is **ready for Google Maps integration**. All infrastructure is in place.

### Validation Results
```
Passed:   11
Warnings: 2  (non-blocking - just need API key configuration)
Failed:   0
```

---

## What You Need to Do

### 1. Get a Google Maps API Key (5 minutes)

1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use existing)
3. Enable APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Geocoding API** (for reverse address lookup)
4. Go to **Credentials** → **Create API Key**
5. Restrict key to:
   - Android package: `com.freshharvest.grocery_app`
   - iOS bundle ID: (verify in `ios/Runner/Info.plist`)

### 2. Add to Android (local.properties)

```properties
MAPS_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

File location: `android/local.properties` (create if missing)

### 3. Add to iOS (Info.plist)

Edit `ios/Runner/Info.plist` and add:

```xml
<key>com.google.ios.maps</key>
<string>YOUR_ACTUAL_API_KEY_HERE</string>
```

### 4. Build with Maps Enabled

```bash
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true
```

---

## How It Works (End-to-End)

### User Flow

1. **User opens address book**
   ↓
2. **Clicks "Choose a map pin (optional)"**
   ↓
3. **Interactive map opens** (Google Maps)
   - Default center: Kathmandu
   - User taps to place marker
   ↓
4. **User taps "Use this location"**
   ↓
5. **Reverse geocoding** (app converts lat/lng to address)
   - Street: `Pulchowk, Lalitpur`
   - City: `Lalitpur`
   - Province: `Bagmati`
   ↓
6. **Address form auto-fills** with geocoded values
   ↓
7. **User reviews/edits fields** (if needed)
   ↓
8. **User saves address**

### Data Flow

```
Flutter App                  Backend                 CockroachDB
===========                  =======                 ===========

GoogleMap
  ↓ (tap on map)
LatLng(27.6742, 85.3242)
  ↓
Geocoding.placemarkFromCoordinates()
  ↓
Street, City, Province
  ↓
POST /account/addresses
  {
    "title": "Home",
    "street": "Pulchowk, Lalitpur",
    "city": "Lalitpur",
    "province": "Bagmati",
    "latitude": 27.6742,
    "longitude": 85.3242
  }
  ↓                          Validate & Store
                             ↓
                    INSERT INTO Address (
                      addressLine1,
                      city,
                      province,
                      latitude,
                      longitude,
                      ...
                    ) VALUES (...)
                             ↓
                          Stored in DB
```

### Delivery Assignment

When admin assigns delivery:

```
GET /delivery/assignments
  ↓
Response includes:
  {
    "order": {
      "address": "Pulchowk, Lalitpur",
      "latitude": 27.6742,
      "longitude": 85.3242
    }
  }
  ↓
Delivery staff can:
- See full address
- See exact location on map
- Navigate with external maps app
```

---

## Database Schema (CockroachDB)

### ✅ Already Exists - No Changes Needed

The `Address` table already has everything needed:

```sql
CREATE TABLE "Address" (
  id           STRING PRIMARY KEY,        -- Unique address ID
  userId       STRING NOT NULL,           -- Customer who owns this
  label        STRING,                    -- "Home", "Work", etc.
  fullName     STRING NOT NULL,           -- Recipient name
  phone        STRING NOT NULL,           -- Recipient phone
  addressLine1 STRING NOT NULL,           -- Street (from map or manual)
  addressLine2 STRING,                    -- Landmark (optional)
  city         STRING NOT NULL,           -- City
  district     STRING,                    -- District
  province     STRING,                    -- Province
  postalCode   STRING,                    -- Postal code
  instructions STRING,                    -- Special instructions
  latitude     FLOAT,                     -- Latitude (from map)
  longitude    FLOAT,                     -- Longitude (from map)
  isDefault    BOOLEAN DEFAULT false,     -- Default delivery address
  createdAt    TIMESTAMP DEFAULT now(),
  updatedAt    TIMESTAMP,
  
  FOREIGN KEY (userId) REFERENCES "User"(id) ON DELETE CASCADE,
  INDEX ON (userId)
);
```

### What This Means

- ✅ Coordinates are stored as nullable floats (handles both map-picked and manual entries)
- ✅ Indexed on `userId` (fast customer lookups)
- ✅ Linked to User and Order tables (complete audit trail)
- ✅ No schema migrations required

### Optional Future Enhancement (Not Needed Yet)

If you later want **distance-based delivery filtering** (show deliveries within 5km):

You can add geospatial indexing, but **not required** for basic maps functionality. Start without it.

---

## What's Already Built for You

### Frontend (Flutter)
- ✅ `AddressMapPicker` widget (full-screen interactive map)
- ✅ Location permission handling (geolocator plugin)
- ✅ Reverse geocoding (geocoding plugin)
- ✅ Address model with latitude/longitude fields
- ✅ Address book integration (calls map picker from address form)

### Backend (Node.js + Prisma)
- ✅ `POST /account/addresses` (create with coordinates)
- ✅ `PATCH /account/addresses/:id` (update with coordinates)
- ✅ `GET /account/addresses` (retrieve all with coordinates)
- ✅ `GET /delivery/assignments` (returns coordinates to delivery staff)
- ✅ Database schema ready

### Infrastructure
- ✅ `google_maps_flutter` plugin in pubspec.yaml
- ✅ `geolocator` for location access
- ✅ `geocoding` for reverse address lookup
- ✅ Android permissions declared
- ✅ iOS permissions configured
- ✅ AndroidManifest.xml set up for API key injection

---

## Testing Checklist

After API key setup:

- [ ] Build Flutter app with `--dart-define=GOOGLE_MAPS_CONFIGURED=true`
- [ ] On address book screen, tap "Choose a map pin"
- [ ] Map displays with default center
- [ ] Tap on map to place marker
- [ ] Tap "Use this location"
- [ ] Address fields auto-populate (street, city, province)
- [ ] Edit fields if needed
- [ ] Save address
- [ ] Verify coordinates stored in database:
  ```sql
  SELECT latitude, longitude FROM "Address"
  WHERE userId = '<your-user-id>'
  ORDER BY createdAt DESC LIMIT 1;
  ```
- [ ] In admin delivery assignment, verify coordinates visible
- [ ] Delivery staff can see lat/lng in assignment details

---

## Quick Reference

### Files You Modified
- None yet! Just configure the API key.

### Key Files to Know
- **Map Picker**: `lib/screens/profile/address_map_picker.dart`
- **Address Form**: `lib/screens/profile/address_book_screen.dart`
- **Address Model**: `lib/models/address.dart`
- **Backend API**: `backend/src/routes/account.ts`
- **Database Schema**: `backend/prisma/schema.prisma` (Address model)

### Build Commands
```bash
# Without maps (fallback to manual entry)
flutter run

# With maps enabled (requires MAPS_API_KEY set)
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true

# Release build with maps
flutter build apk --release --dart-define=GOOGLE_MAPS_CONFIGURED=true
flutter build ios --release --dart-define=GOOGLE_MAPS_CONFIGURED=true
```

### Validation Script
Run anytime to check setup:
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-maps-setup.ps1
```

---

## Troubleshooting

### "Map pin is unavailable" appears
→ You built without `--dart-define=GOOGLE_MAPS_CONFIGURED=true`

### Map shows blank/white screen
→ API key not set or incorrect
→ Check `adb logcat` for `GoogleMapsInitializationException`

### Geocoding fails (address not found)
→ Geocoding API not enabled in Google Cloud Console
→ Check that API key allows Geocoding API

### Coordinates not stored
→ Check backend logs: `npm run dev`
→ Verify POST request body includes `latitude` and `longitude`

### iOS build fails
→ Ensure iOS API key added to `ios/Runner/Info.plist`
→ Run `flutter clean && flutter pub get`

---

## Summary

| Aspect | Status | Action |
|--------|--------|--------|
| **Flutter Components** | ✅ Ready | None |
| **Backend API** | ✅ Ready | None |
| **Database Schema** | ✅ Ready | None |
| **Plugins** | ✅ Ready | None |
| **Android Setup** | ⚠️ Needs Key | Add to `local.properties` |
| **iOS Setup** | ⚠️ Needs Key | Add to `Info.plist` |
| **Overall** | 🟢 Ready | Get API key and test |

---

## Related Documentation

See these files for detailed setup instructions:

1. [GOOGLE_MAPS_SETUP.md](./GOOGLE_MAPS_SETUP.md) - Complete setup guide for Android & iOS
2. [COCKROACHDB_MAPS_CHANGES.md](./COCKROACHDB_MAPS_CHANGES.md) - Database schema deep-dive
3. [README.md](./README.md) - Project overview

Run validation:
```bash
.\scripts\validate-maps-setup.ps1
```
