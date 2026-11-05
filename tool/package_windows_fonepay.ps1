param([string]$PackageName = 'FastStore-Windows-3.2.0-Auto-PDF-20261105')
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$release = Join-Path $workspace 'build/windows/x64/runner/Release'
$packageName = $PackageName
if ($packageName -notmatch '^FastStore-Windows-[A-Za-z0-9.-]+$') { throw 'Invalid package name.' }
$package = Join-Path $workspace $packageName
$archive = "$package.zip"
$versionText = Get-Content -LiteralPath (Join-Path $workspace 'pubspec.yaml') -Raw
$appVersion = [regex]::Match($versionText, '(?m)^version:\s*(\S+)').Groups[1].Value
if (!$appVersion) { throw 'App version is missing.' }
if ((Test-Path -LiteralPath $package) -or (Test-Path -LiteralPath $archive)) {
  throw 'The destination already exists. Review it before creating a replacement.'
}
if (!(Test-Path -LiteralPath (Join-Path $release 'RamPrasadBilling.exe')) -or
    !(Test-Path -LiteralPath (Join-Path $release 'data/app.so'))) {
  throw 'The complete normal Windows Release build is missing.'
}
$binaryVersion = (Get-Item -LiteralPath (Join-Path $release 'RamPrasadBilling.exe')).VersionInfo.ProductVersion
if ($binaryVersion -ne $appVersion) { throw "Stale executable: $binaryVersion; expected $appVersion. Rebuild Windows Release first." }
New-Item -ItemType Directory -Path $package | Out-Null
Copy-Item -LiteralPath (Join-Path $release 'RamPrasadBilling.exe') -Destination $package
Get-ChildItem -LiteralPath $release -File -Filter '*.dll' | Copy-Item -Destination $package
Copy-Item -LiteralPath (Join-Path $release 'data') -Destination $package -Recurse
$docs = Join-Path $package 'docs'
New-Item -ItemType Directory -Path $docs | Out-Null
Copy-Item -LiteralPath (Join-Path $workspace 'docs/FONEPAY_SETUP.md') -Destination $docs
Copy-Item -LiteralPath (Join-Path $workspace 'docs/STATIC_FONEPAY_SETUP.md') -Destination $docs
Copy-Item -LiteralPath (Join-Path $workspace 'docs/RELEASE_v3.2.0.md') -Destination $docs
@"
FastStore / Ram Prasad General Store - Windows x64
Application version: $appVersion
Package: 5 November 2026
Includes local customer/phone selection, basket session recovery, responsive
update downloads, manual Fonepay verification and bill PAN 300854653.
Offline Customers is below Expiry in the main menu. Create customer profiles
with name, phone, address and optional email; click a customer to view bills.
Pending cash CSV exports preserve manual rows and append new bills at the bottom.
Save and close the CSV in Excel before the app updates it. Do not rename headers.
Returns & Exchanges has customer/phone/bill search and a date filter.
Printed bills are automatically archived under C:/Ramprasad store/bills/pdf/
using their POS reference as the filename, without a Save As prompt. Reprints
reuse the filename. The archive is written even if printer selection is cancelled.

HOW TO RUN
1. Extract this entire ZIP into a new application folder on the billing computer.
2. Close the old app and open RamPrasadBilling.exe from the extracted folder.
3. Keep every DLL and the data folder beside the executable.
4. Keep C:/Ramprasad store/ and existing bills/customer files intact.
5. If Windows reports missing MSVCP/VCRUNTIME DLLs, install the official
   Microsoft Visual C++ x64 Redistributable:
   https://aka.ms/vs/17/release/vc_redist.x64.exe

PAYMENT STATUS - READ BEFORE USE
eSewa / QR uses the owner's newly supplied eSewa Circle QR. The customer
must enter the exact displayed NPR amount. The cashier must verify the incoming
payment by ticking the confirmation checkbox before creating and printing a bill.
No transaction reference or automatic bank verification is required.
Cancel before confirmation creates no bill.
The new QR image is bundled unchanged and works offline.
Tick the checkbox to acknowledge receipt, then create and print the bill.
See docs/STATIC_FONEPAY_SETUP.md. An unreadable QR disables confirmation.
No Fonepay API is required for this manual flow. Cash billing remains available.
Failed printing can be retried using the same saved bill without another payment.

BACKEND DEPLOYMENT
Deploy the matching backend before online manual Fonepay checkout. The manual
flow requires no new database migration. This ZIP does not deploy the backend.
The older dynamic API integration remains separate; see docs/FONEPAY_SETUP.md.
No merchant secrets, account sessions or business records are included.

CONTENTS AND VALIDATION
This is the actual lib/main.dart Windows Release application, not a test harness.
The package includes the executable, runtime/plugin DLLs and Flutter data assets.
The preceding source validation passed 284 Flutter tests and backend checks.
No real bank transaction or physical printer certification was performed.
FILES-SHA256.txt records the packaged file hashes.
"@ | Set-Content -LiteralPath (Join-Path $package 'README.txt') -Encoding UTF8
$hashLines = Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object {
  $relative = $_.FullName.Substring($package.Length + 1).Replace('\', '/')
  '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
}
$hashLines | Set-Content -LiteralPath (Join-Path $package 'FILES-SHA256.txt') -Encoding UTF8
Compress-Archive -LiteralPath $package -DestinationPath $archive -CompressionLevel Optimal
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
  $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
  foreach ($required in @('RamPrasadBilling.exe', 'flutter_windows.dll', 'data/app.so', 'data/flutter_assets/assets/images/business_esewa_qr.jpeg', 'README.txt', 'docs/FONEPAY_SETUP.md', 'docs/STATIC_FONEPAY_SETUP.md', 'docs/RELEASE_v3.2.0.md', 'FILES-SHA256.txt')) {
    if ($names -notcontains "$packageName/$required") { throw "Missing ZIP entry: $required" }
  }
  if ($names | Where-Object { $_ -match '(^|/)(\.env|RamPrasadStore\.exe)$|\.pdb$|\.lib$|\.exp$' }) {
    throw 'Unexpected private/development or obsolete executable in package.'
  }
  $entryCount = $zip.Entries.Count
} finally { $zip.Dispose() }
$zipHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$zipHash  $packageName.zip" | Set-Content -LiteralPath "$archive.sha256" -Encoding ASCII
[PSCustomObject]@{ Zip = $archive; SizeMB = [Math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 2); Entries = $entryCount; SHA256 = $zipHash } | Format-List
