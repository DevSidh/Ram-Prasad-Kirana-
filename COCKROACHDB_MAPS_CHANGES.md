# CockroachDB Schema for Maps Integration

## TL;DR
**No schema changes required.** Your existing Address table already has `latitude` and `longitude` fields (Float nullable columns). They're ready to store map-picked coordinates.

---

## Current Address Schema (Already Sufficient)

```sql
model Address {
  id           String   @id @default(cuid())
  userId       String
  label        String?
  fullName     String
  phone        String
  addressLine1 String
  addressLine2 String?
  city         String
  district     String?
  province     String?
  postalCode   String?
  instructions String?
  latitude     Float?               ← Already present
  longitude    Float?               ← Already present
  isDefault    Boolean  @default(false)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  orders       Order[]

  @@index([userId])
}
```

### How It Works
1. When a user picks a location on the Google Map, the Flutter app receives:
   - `latitude` (Float, e.g., 27.6742)
   - `longitude` (Float, e.g., 85.3242)
   - `street`, `city`, `province` (from reverse geocoding)

2. Flutter sends these to the backend:
   ```json
   POST /account/addresses
   {
     "latitude": 27.6742,
     "longitude": 85.3242,
     "street": "Pulchowk, Lalitpur",
     "city": "Lalitpur",
     "province": "Bagmati"
   }
   ```

3. Backend validates and stores in Address table:
   - `addressLine1` ← street
   - `city` ← city
   - `province` ← province
   - `latitude` ← latitude
   - `longitude` ← longitude

4. On delivery assignment, the delivery staff sees:
   ```json
   GET /delivery/assignments
   {
     "assignments": [
       {
         "order": {
           "address": "Pulchowk, Lalitpur, Bagmati",
           "latitude": 27.6742,
           "longitude": 85.3242
           ...
         }
       }
     ]
   }
   ```

---

## Database Validation (Nothing to Do)

The Address table structure is correct for maps:
- ✅ `latitude` and `longitude` are nullable floats (handles both map-picked and manual entries)
- ✅ Indexed on `userId` (fast lookups per customer)
- ✅ FK to User with cascade delete (clean removal)
- ✅ ISO timestamps for audit trail
- ✅ Addresses linked to orders (delivery staff can navigate)

---

## Optional Future Enhancements (Not Needed Now)

If you later want **distance-based filtering** (e.g., "show deliveries near me"):

### Option 1: Simple Haversine Distance (App-Side)
App calculates distance in Dart using the haversine formula:
```dart
double haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * asin(sqrt(a));
  return R * c;
}
```
No database changes needed.

### Option 2: CockroachDB Native Geospatial Queries
CockroachDB supports `geometry` and `geography` types. To add spatial indexing:

```sql
ALTER TABLE "Address" 
ADD COLUMN "location" geometry;

-- Populate existing rows
UPDATE "Address" 
SET "location" = ST_Point(longitude, latitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Create spatial index
CREATE INDEX "Address_location_idx" 
ON "Address" USING GIST("location");
```

Then query by distance:
```sql
SELECT * FROM "Address"
WHERE ST_Distance(location, ST_Point(85.3240, 27.7172)) < 5000 -- within 5km
ORDER BY ST_Distance(location, ST_Point(85.3240, 27.7172));
```

**Cost**: Small storage overhead (~32 bytes per address), more complex Prisma schema.
**Benefit**: Sub-millisecond geographic queries if you have 100k+ deliveries.

**Recommendation**: Start without geospatial queries. Implement if delivery staff can't find nearby orders (unlikely until you scale).

---

## Migration Steps (If You Later Add Geospatial Index)

Only do this **after** maps are working and addresses have coordinates:

### Step 1: Create Prisma Migration
```bash
cd backend
npx prisma migrate dev --name add_location_index
```

### Step 2: Edit Migration File
File: `backend/prisma/migrations/<timestamp>_add_location_index/migration.sql`

```sql
-- Unlock Address table (required for CockroachDB schema changes)
ALTER TABLE "Address" SET (schema_locked = false);

-- Add geometry column
ALTER TABLE "Address" 
ADD COLUMN "location" geometry;

-- Populate existing rows
UPDATE "Address" 
SET "location" = ST_Point(longitude, latitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Create spatial index
CREATE INDEX "Address_location_idx" 
ON "Address" USING GIST("location");

-- Re-lock Address table
ALTER TABLE "Address" SET (schema_locked = true);
```

### Step 3: Deploy Migration
```bash
npx prisma migrate deploy
```

### Step 4: Update Prisma Schema (prisma/schema.prisma)
```prisma
model Address {
  ...existing fields...
  latitude     Float?
  longitude    Float?
  location     Geometry? @db.Geometry("point", 2) // New field
  
  @@index([userId])
  @@index([location], type: "gist") // Spatial index
}
```

### Step 5: Restart Backend
```bash
npm run dev
```

---

## Monitoring Coordinates in CockroachDB

Once addresses are stored, verify they have coordinates:

```sql
-- Check how many addresses have coordinates
SELECT 
  COUNT(*) as total,
  COUNT(latitude) as with_coordinates,
  ROUND(COUNT(latitude)::FLOAT / COUNT(*) * 100, 2) as percentage
FROM "Address";

-- Find coordinates
SELECT 
  id, label, city, addressLine1, latitude, longitude
FROM "Address"
WHERE latitude IS NOT NULL
ORDER BY "createdAt" DESC
LIMIT 10;
```

Expected output after testing:
```
 total | with_coordinates | percentage
-------|------------------|----------
  50   |       5          |  10.00
```

---

## Troubleshooting CockroachDB Issues

### Error: "schema change is disallowed because table 'Address' is locked"
This happens when:
1. You have a changefeed monitoring the Address table
2. CockroachDB locked it to improve changefeed performance

**Solution** (if you need to modify schema):
```sql
ALTER TABLE "Address" SET (schema_locked = false);
-- Apply your schema change
ALTER TABLE "Address" SET (schema_locked = true);
```

Safer approach: Let the Prisma migration handle this automatically (include `SET (schema_locked = false)` at start of migration).

### P1001: "Can't reach database server"
Your recent backend logs show intermittent P1001 errors.

**Causes**:
1. CockroachDB cluster is temporarily down/unavailable
2. Network timeout (check firewall/VPN)
3. Connection string has expired credentials
4. Too many concurrent connections

**Steps to diagnose**:
```sql
-- From CockroachDB Admin Console
SELECT 
  node_id, 
  uptime,
  status
FROM crdb_internal.nodes;

-- Check active connections from your backend
SHOW SESSIONS;
```

**Solution**:
1. Verify backend `.env` has correct `DATABASE_URL`
2. Test connection: `psql $DATABASE_URL -c "SELECT 1;"`
3. Reduce Prisma connection pool size if hitting limits:
   ```
   DATABASE_URL="postgres://...?connection_limit=10"
   ```
4. Increase transaction timeout (currently 5000ms in inventory.ts):
   ```typescript
   await prisma.$transaction(
     async (tx) => { ... },
     { timeout: 10000 } // Increase from 5000
   )
   ```

---

## Summary

| Question | Answer |
|----------|--------|
| **Do I need to change CockroachDB schema for maps?** | No. Existing `latitude` and `longitude` columns are sufficient. |
| **What fields store map coordinates?** | `Address.latitude` and `Address.longitude` (Float nullable). |
| **Do I need a geospatial index?** | Not yet. Add only if you later implement distance-based queries. |
| **How does the data flow?** | Map (Flutter) → API (Backend) → Database (CockroachDB) |
| **What if a user doesn't pick a location?** | Fields stay NULL; address still saved with manual street/city/province. |

**Next Step**: Implement the Flutter map picker using the [GOOGLE_MAPS_SETUP.md](./GOOGLE_MAPS_SETUP.md) guide.
