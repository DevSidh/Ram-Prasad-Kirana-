# Google Maps Integration - Quick Start (10 Minutes)

## Step 1: Get Google Maps API Key (5 min)

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Click "Select a Project" → "New Project" → name it "FreshHarvest"
3. Wait for project to create
4. Search for and enable these APIs (3 separate searches):
   - "Maps SDK for Android" → Click "Enable"
   - "Maps SDK for iOS" → Click "Enable"
   - "Geocoding API" → Click "Enable"
5. Go to "Credentials" (left sidebar)
6. Click "Create Credentials" → "API Key"
7. Copy your API key (looks like: `AIzaSyD...`)

---

## Step 2: Configure Android (2 min)

1. Open `android/local.properties`
2. If file doesn't exist, create it
3. Add this line:
   ```
   MAPS_API_KEY=YOUR_KEY_HERE
   ```
   (Replace `YOUR_KEY_HERE` with the key you copied)

Example:
```properties
flutter.sdk=C:\\flutter
MAPS_API_KEY=AIzaSyD1234567890abcdefghijklmnop
```

---

## Step 3: Configure iOS (2 min)

1. Open `ios/Runner/Info.plist`
2. Find the closing `</dict>` tag at the very end
3. Add these lines BEFORE `</dict>`:
   ```xml
   <key>com.google.ios.maps</key>
   <string>YOUR_KEY_HERE</string>
   ```
   (Replace `YOUR_KEY_HERE` with your API key)

Example ending:
```xml
   ...
   <key>com.google.ios.maps</key>
   <string>AIzaSyD1234567890abcdefghijklmnop</string>
</dict>
</plist>
```

---

## Step 4: Test (1 min)

```bash
# Navigate to project
cd E:\freshharvest-groceries-oct-7-2026-7-08-39-pm

# Run with maps enabled
flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true
```

### What to Test
1. Tap your profile → "Delivery Addresses"
2. Click "Add address" or "Edit"
3. Click "Choose a map pin (optional)"
4. You should see an interactive map
5. Tap on the map to place a marker
6. Tap "Use this location"
7. Address fields should auto-fill
8. Save address

---

## Step 5: Verify in Database (Optional)

After saving an address with map coordinates:

```bash
# Connect to your CockroachDB from terminal
psql "postgresql://user:password@host:26257/database"

# Query to see coordinates
SELECT id, label, street, city, latitude, longitude 
FROM "Address" 
WHERE userId = 'YOUR_USER_ID' 
ORDER BY "createdAt" DESC 
LIMIT 5;
```

You should see latitude and longitude populated.

---

## Validation

Run this to verify everything is set up:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-maps-setup.ps1
```

---

## Build for Production

With maps:
```bash
flutter build apk --release --dart-define=GOOGLE_MAPS_CONFIGURED=true
flutter build ios --release --dart-define=GOOGLE_MAPS_CONFIGURED=true
```

Without maps (fallback to manual):
```bash
flutter build apk --release
flutter build ios --release
```

---

## Troubleshooting

### Map appears blank
- API key not set correctly
- API key not enabled for your package/bundle ID
- Run validation script to check

### "Map pin is unavailable"
- You didn't add `--dart-define=GOOGLE_MAPS_CONFIGURED=true` to flutter run
- Try: `flutter run --dart-define=GOOGLE_MAPS_CONFIGURED=true`

### Address doesn't auto-fill
- Geocoding API not enabled in Google Cloud Console
- Check backend logs for API errors

### Build fails
- Run `flutter clean && flutter pub get`
- Ensure `android/local.properties` has MAPS_API_KEY
- Ensure `ios/Runner/Info.plist` has the XML key added correctly

---

## That's It!

Your app now supports:
✅ Interactive map location picker
✅ Automatic address lookup from coordinates
✅ Delivery staff can see customer location on map
✅ Database stores coordinates for future features

For detailed docs, see:
- [MAPS_INTEGRATION_SUMMARY.md](./MAPS_INTEGRATION_SUMMARY.md)
- [GOOGLE_MAPS_SETUP.md](./GOOGLE_MAPS_SETUP.md)
- [COCKROACHDB_MAPS_CHANGES.md](./COCKROACHDB_MAPS_CHANGES.md)
