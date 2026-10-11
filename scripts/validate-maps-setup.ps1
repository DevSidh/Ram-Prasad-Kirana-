#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Validates FreshHarvest Google Maps setup before building.

.DESCRIPTION
    Checks that all prerequisites for Google Maps integration are in place:
    - API key configuration for Android
    - iOS Info.plist setup (manual, but checked)
    - Location permissions declared
    - AddressMapPicker component exists
    - Geocoding and google_maps_flutter plugins in pubspec

.EXAMPLE
    .\scripts\validate-maps-setup.ps1
    .\scripts\validate-maps-setup.ps1 -Verbose
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'
$checks = @{
    passed = 0
    failed = 0
    warnings = 0
}

function Write-Check {
    param(
        [string]$status,
        [string]$message,
        [string]$detail = ""
    )
    
    switch ($status) {
        "pass" { 
            $icon = "[PASS]"
            $checks.passed++
            $color = "Green"
        }
        "fail" { 
            $icon = "[FAIL]"
            $checks.failed++
            $color = "Red"
        }
        "warn" { 
            $icon = "[WARN]"
            $checks.warnings++
            $color = "Yellow"
        }
        default { 
            $icon = "[INFO]"
            $color = "Gray"
        }
    }
    
    Write-Host "$icon $message" -ForegroundColor $color
    if ($detail -and $Verbose) {
        Write-Host "    $detail" -ForegroundColor DarkGray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Google Maps Setup Validation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check 1: Android local.properties
Write-Host "Checking Android Configuration..." -ForegroundColor Blue
if (Test-Path "android/local.properties") {
    $localProps = Get-Content "android/local.properties"
    $mapsProperty = $localProps |
        Where-Object { $_ -match '^\s*(googleMapsApiKey|MAPS_API_KEY)\s*=' } |
        Select-Object -Last 1
    if ($mapsProperty -match '^\s*(googleMapsApiKey|MAPS_API_KEY)\s*=\s*(.+?)\s*$') {
        $apiKey = $Matches[2]
        if ($apiKey -and $apiKey -notmatch '^YOUR_') {
            Write-Check "pass" "Android API key configured in local.properties"
        } else {
            Write-Check "warn" "Android API key is a placeholder" "Set googleMapsApiKey=<restricted-key>"
        }
    } else {
        Write-Check "warn" "Google Maps key not found in local.properties" "Add googleMapsApiKey=<restricted-key>"
    }
} else {
    Write-Check "warn" "android/local.properties not found" "Create it with googleMapsApiKey=<restricted-key>"
}

# Check 2: AndroidManifest.xml has meta-data
Write-Host ""
Write-Host "Checking AndroidManifest.xml..." -ForegroundColor Blue
$manifest = Get-Content "android/app/src/main/AndroidManifest.xml" -Raw
if ($manifest -match "com.google.android.geo.API_KEY") {
    Write-Check "pass" "AndroidManifest.xml has Google Maps meta-data"
} else {
    Write-Check "fail" "AndroidManifest.xml missing Google Maps API key meta-data"
}

if ($manifest -match "ACCESS_FINE_LOCATION" -and $manifest -match "ACCESS_COARSE_LOCATION") {
    Write-Check "pass" "Location permissions declared in AndroidManifest.xml"
} else {
    Write-Check "fail" "Location permissions missing from AndroidManifest.xml"
}

# Check 3: iOS Info.plist
Write-Host ""
Write-Host "Checking iOS Configuration (Manual Check Required)..." -ForegroundColor Blue
if (Test-Path "ios/Runner/Info.plist") {
    $infoPlist = Get-Content "ios/Runner/Info.plist" -Raw
    if ($infoPlist -match "GoogleMapsApiKey") {
        Write-Check "warn" "iOS Info.plist reads the Google Maps build setting" "Set GOOGLE_MAPS_API_KEY in the Runner target's Xcode build settings."
    } else {
        Write-Check "fail" "iOS Info.plist is missing GoogleMapsApiKey"
    }
    
    if ($infoPlist -match "NSLocationWhenInUseUsageDescription" -or `
        $infoPlist -match "NSLocationAlwaysAndWhenInUseUsageDescription") {
        Write-Check "pass" "iOS location permission descriptions present"
    } else {
        Write-Check "warn" "iOS location permission descriptions missing" "Add to Info.plist for runtime permission"
    }
} else {
    Write-Check "fail" "ios/Runner/Info.plist not found"
}

# Check 4: Pubspec dependencies
Write-Host ""
Write-Host "Checking Flutter Dependencies..." -ForegroundColor Blue
$pubspec = Get-Content "pubspec.yaml" -Raw
$requiredPackages = @(
    "google_maps_flutter"
    "geolocator"
    "geocoding"
)

foreach ($pkg in $requiredPackages) {
    if ($pubspec -match "^\s*$pkg\s*:" -or $pubspec -match "`n\s+$pkg\s*:") {
        Write-Check "pass" "$pkg package in pubspec.yaml"
    } else {
        Write-Check "fail" "$pkg package NOT in pubspec.yaml" "Run: flutter pub add $pkg"
    }
}

# Check 5: AddressMapPicker exists
Write-Host ""
Write-Host "Checking Flutter Components..." -ForegroundColor Blue
if (Test-Path "lib/screens/profile/address_map_picker.dart") {
    $mapPicker = Get-Content "lib/screens/profile/address_map_picker.dart" -Raw
    if ($mapPicker -match "class AddressMapPicker") {
        Write-Check "pass" "AddressMapPicker component exists"
    } else {
        Write-Check "fail" "AddressMapPicker class not found in file"
    }
    
    if ($mapPicker -match "GoogleMap" -and $mapPicker -match "onTap") {
        Write-Check "pass" "AddressMapPicker renders a tappable Google map"
    }
} else {
    Write-Check "fail" "lib/screens/profile/address_map_picker.dart not found"
}

if (Test-Path "lib/screens/profile/address_book_screen.dart") {
    $addressBook = Get-Content "lib/screens/profile/address_book_screen.dart" -Raw
    if ($addressBook -match "AddressMapPicker" -or $addressBook -match "_chooseMapLocation") {
        Write-Check "pass" "Address book screen integrates map picker"
    }
} else {
    Write-Check "warn" "lib/screens/profile/address_book_screen.dart not found"
}

# Check 6: Address model supports coordinates
Write-Host ""
Write-Host "Checking Data Models..." -ForegroundColor Blue
if (Test-Path "lib/models/address.dart") {
    $addressModel = Get-Content "lib/models/address.dart" -Raw
    if ($addressModel -match "latitude" -and $addressModel -match "longitude") {
        Write-Check "pass" "Address model has latitude/longitude fields"
    } else {
        Write-Check "fail" "Address model missing coordinate fields"
    }
}

# Check 7: Backend schema (optional, for reference)
Write-Host ""
Write-Host "Checking Backend (Optional Reference)..." -ForegroundColor Blue
if (Test-Path "backend/prisma/schema.prisma") {
    $schema = Get-Content "backend/prisma/schema.prisma" -Raw
    if ($schema -match "model Address" -and `
        $schema -match "latitude\s+Float\?" -and `
        $schema -match "longitude\s+Float\?") {
        Write-Check "pass" "CockroachDB Address schema supports coordinates"
    } else {
        Write-Check "warn" "Address schema may not have coordinate fields (check schema.prisma)"
    }
} else {
    Write-Check "warn" "Backend Prisma schema not found (optional check)"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$total = $checks.passed + $checks.failed + $checks.warnings

Write-Host "Passed:  " -NoNewline -ForegroundColor Green
Write-Host $checks.passed -ForegroundColor Green
Write-Host "Failed:  " -NoNewline
if ($checks.failed -gt 0) { Write-Host $checks.failed -ForegroundColor Red } 
else { Write-Host $checks.failed -ForegroundColor Green }
Write-Host "Warnings:" -NoNewline
if ($checks.warnings -gt 0) { Write-Host $checks.warnings -ForegroundColor Yellow } 
else { Write-Host $checks.warnings -ForegroundColor Green }

Write-Host "`n"

if ($checks.failed -eq 0) {
    Write-Host "Source checks passed. Resolve platform-key warnings before testing the map." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Set googleMapsApiKey in android/local.properties"
    Write-Host "2. Set GOOGLE_MAPS_API_KEY in the iOS Runner build settings"
    Write-Host "3. Build normally; no GOOGLE_MAPS_CONFIGURED define is required"
    Write-Host ""
    exit 0
} else {
    Write-Host "Please fix the failures above before building with maps." -ForegroundColor Red
    Write-Host ""
    exit 1
}
