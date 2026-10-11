# Google Maps Integration Setup Guide for FreshHarvest

## Overview
Your app is ready for Google Maps integration! The Flutter app has:
- ✅ `google_maps_flutter` plugin installed in pubspec.yaml
- ✅ Web Maps JavaScript API loader for Chrome
- ✅ Location permission handling (geolocator + geocoding)
- ✅ Address model with latitude/longitude fields
- ✅ AddressMapPicker screen (already built but needs API key configuration)
- ✅ Backend API support for storing coordinates (latitude, longitude in Address model)

The backend CockroachDB schema **already has** the required fields. **No schema changes needed.**

---

## Part 1: Get a Google Maps API Key

### Step 1: Go to Google Cloud Console
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use an existing one)
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Maps JavaScript API** (for Chrome/web)
   - **Geocoding API** (for address reversal)

### Step 2: Create an API Key
1. Go to **Credentials** > **Create Credentials** > **API Key**
2. Copy the API key
3. **Restrict the key** to:
   - Use separate restricted keys for Android, iOS, and web
   - For web, set HTTP referrer restrictions for your development and production origins
   - **API restrictions**: Maps SDK for Android/iOS or Maps JavaScript API, as applicable

### Step 3: Restrict by App Package and Signing Certificate
- For **Android**: Add package name `com.freshharvest.grocery_app` with SHA-1 fingerprint
- For **iOS**: Add bundle ID (check Info.plist)

---

## Part 2: Configure Android

### Step 1: Add API Key to build.gradle.properties
Edit `android/local.properties` (or create it if missing):

```properties
# Google Maps API Key for Android
MAPS_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

### Step 2: Verify AndroidManifest.xml
The file `android/app/src/main/AndroidManifest.xml` already has:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${MAPS_API_KEY}" />
```

This automatically picks up the key from `local.properties` at build time.

### Step 3: Add Location Permissions
Already in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### Step 4: Build and Test
```bash
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true
```

---

## Part 3: Configure iOS

### Step 1: Edit ios/Runner/GeneratedPluginRegistrant.m or Info.plist

Add the API key to `ios/Runner/Info.plist`:

```xml
<key>com.google.ios.maps</key>
<string>YOUR_ACTUAL_API_KEY_HERE</string>
```

Or configure via CocoaPods in `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'GOOGLE_MAPS_ENABLED=1'
      ]
    end
  end
end
```

### Step 2: Update iOS Bundle ID
In `ios/Runner/Info.plist`, ensure the bundle ID matches what you registered:
```xml
<key>CFBundleIdentifier</key>
<string>com.freshharvest.grocery_app</string>
```

### Step 3: Build for iOS
```bash
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true -t ios
```

---

## Part 4: Enable the Map Picker in Flutter

### Current Status
The picker uses native Maps SDKs on Android/iOS. Chrome needs the Maps JavaScript API key loaded before Flutter starts:

1. Copy `web/maps-config.example.js` to `web/maps-config.js`.
2. Set `window.GOOGLE_MAPS_API_KEY` in the copied file to a web key restricted to your site's HTTP referrers and the Maps JavaScript API.
3. Start/build web with `--dart-define=GOOGLE_MAPS_CONFIGURED=true`.

Until that define is enabled, web users see a manual-entry message instead of a blank map. Android/iOS remain enabled by default and need their own correctly restricted native keys.

### How It Works
1. **User taps "Choose a map pin (optional)"** in address form
2. App opens full-screen GoogleMap with:
   - **Default center**: Kathmandu (26.7288°N, 85.9263°E) — adjust for your delivery area
   - **Interaction**: User taps the map to place a marker
   - **Reverse geocoding**: Taps "Use this location" → geocoding API converts lat/lng to street address
3. **Address fields auto-populate** with street, city, province
4. User can manually adjust if needed
5. **Coordinates stored** in Address.latitude and Address.longitude
6. **Backend receives** full address data via `/account/addresses` POST/PATCH endpoints

---

## Part 5: Database Schema (CockroachDB) — No Changes Needed

Your existing Address schema already supports maps:

```sql
model Address {
  id           String   @id @default(cuid())
  userId       String
  label        String?
  fullName     String
  phone        String
  addressLine1 String    -- Street address from map
  addressLine2 String?   -- Landmark (optional)
  city         String    -- Auto-filled from geocoding
  district     String?
  province     String?   -- Auto-filled from geocoding
  postalCode   String?
  instructions String?
  latitude     Float?    -- Stored from map picker
  longitude    Float?    -- Stored from map picker
  isDefault    Boolean   @default(false)
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  user         User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  orders       Order[]
  
  @@index([userId])
}
```

**What's already indexed:**
- `userId` for fast lookups per customer
- Coordinates are stored as floats for distance queries (future feature)

**Future optimizations** (if you add distance-based filtering):
- Add geospatial index: `CREATE INDEX address_location_idx ON Address USING GIST (ll_to_earth(latitude, longitude));`
- But this requires PostGIS on PostgreSQL, not available on CockroachDB

For now, use coordinates in the app for map display and delivery assignment.

---

## Part 6: Backend API Usage

Your backend already handles maps data. When creating/updating an address:

### POST `/account/addresses`
```json
{
  "title": "Home",
  "fullName": "Siddhant Kumar",
  "phone": "+977-981234567",
  "street": "Pulchowk, Lalitpur",
  "city": "Lalitpur",
  "province": "Bagmati",
  "landmark": "Near Patan Durbar Square",
  "instructions": "Gate B on left side",
  "isDefault": true,
  "latitude": 27.6742,
  "longitude": 85.3242
}
```

The backend automatically:
1. Validates that latitude/longitude are floats
2. Stores them in the Address table
3. Returns them in the address list response

### GET `/account/addresses`
Returns:
```json
{
  "data": [
    {
      "id": "clx...",
      "title": "Home",
      "fullName": "Siddhant Kumar",
      "phone": "+977-981234567",
      "street": "Pulchowk, Lalitpur",
      "city": "Lalitpur",
      "province": "Bagmati",
      "landmark": "Near Patan Durbar Square",
      "instructions": "Gate B on left side",
      "isDefault": true,
      "latitude": 27.6742,
      "longitude": 85.3242
    }
  ]
}
```

---

## Part 7: Testing

### Test Locally (with map disabled)
```bash
flutter run
```
→ Should show "Map pin is unavailable" message, with "Enter address manually" fallback

### Test with Maps (requires API key)
```bash
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true
```
→ Should show interactive map, allow placing a pin, and auto-fill address

### Test Backend
```bash
curl -X POST http://localhost:3000/account/addresses \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Work",
    "fullName": "Siddhant Kumar",
    "phone": "+977-981234567",
    "street": "Bhrikutimandap, Kathmandu",
    "city": "Kathmandu",
    "province": "Bagmati",
    "latitude": 27.7172,
    "longitude": 85.3240
  }'
```

---

## Part 8: Deployment Checklist

- [ ] API key created in Google Cloud Console
- [ ] Android API key configured in `android/local.properties`
- [ ] iOS API key added to `ios/Runner/Info.plist`
- [ ] App signing certificate SHA-1 registered with Google
- [ ] iOS bundle ID registered with Google
- [ ] Build with `--dart-define=GOOGLE_MAPS_CONFIGURED=true`
- [ ] Test map picker end-to-end
- [ ] Test address auto-fill from geocoding
- [ ] Verify coordinates stored in database
- [ ] Test delivery staff can see coordinates in assignment details

---

## Part 9: Troubleshooting

### Map shows blank or "Failed to load map"
→ API key not configured or restricted incorrectly
→ Check `adb logcat` for `GoogleMapsInitializationException`

### "Map pin is unavailable" appears
→ `GOOGLE_MAPS_CONFIGURED=false` (default). Rebuild with `--dart-define=GOOGLE_MAPS_CONFIGURED=true`

### Geocoding fails ("Unable to resolve address")
→ Enable Geocoding API in Google Cloud Console
→ Check that API key has Geocoding API restriction

### Address auto-fill not working
→ Verify geocoding package can access Google's Geocoding API
→ Check network request logs in backend

### Coordinates not stored in database
→ Verify backend is receiving latitude/longitude in request body
→ Check address creation endpoint logs: `/account/addresses` POST

---

## Summary

✅ **Flutter app**: Ready to use map picker (needs API key config only)
✅ **Backend schema**: Supports latitude/longitude (no changes needed)
✅ **API endpoints**: Already handle coordinates in requests/responses
✅ **Android manifest**: Already configured to load key from `local.properties`
✅ **Permissions**: Location permissions already requested

**Next steps:**
1. Get a Google Maps API key from Google Cloud Console
2. Add it to `android/local.properties` (Android) and `ios/Runner/Info.plist` (iOS)
3. Register your app signing certificates with Google
4. Build with `--dart-define=GOOGLE_MAPS_CONFIGURED=true`
5. Test the address map picker end-to-end
