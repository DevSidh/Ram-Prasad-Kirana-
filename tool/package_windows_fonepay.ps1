param([string]$PackageName = 'FastStore-Windows-3.1.4-Fonepay-Checkout-20261104')
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
New-Item -ItemType Directory -Path $package | Out-Null
Copy-Item -LiteralPath (Join-Path $release 'RamPrasadBilling.exe') -Destination $package
Get-ChildItem -LiteralPath $release -File -Filter '*.dll' | Copy-Item -Destination $package
Copy-Item -LiteralPath (Join-Path $release 'data') -Destination $package -Recurse
$docs = Join-Path $package 'docs'
New-Item -ItemType Directory -Path $docs | Out-Null
Copy-Item -LiteralPath (Join-Path $workspace 'docs/FONEPAY_SETUP.md') -Destination $docs
@"
FastStore / Ram Prasad General Store - Windows x64
Application version: $appVersion
Package: Fonepay checkout changes, 4 November 2026
Includes local-only customer selection from saved bills, JSON index and CSV.
Includes clear handling when an older backend lacks the Fonepay config route.

HOW TO RUN
1. Extract this entire ZIP into a new application folder on the billing computer.
2. Close the old app and open RamPrasadBilling.exe from the extracted folder.
3. Keep every DLL and the data folder beside the executable.
4. Keep C:/Ramprasad store/ and existing bills/customer files intact.
5. If Windows reports missing MSVCP/VCRUNTIME DLLs, install the official
   Microsoft Visual C++ x64 Redistributable:
   https://aka.ms/vs/17/release/vc_redist.x64.exe

PAYMENT STATUS - READ BEFORE USE
UPI/static personal QR checkout has been removed. Fonepay uses a pending
checkout, exact saved NPR balance and backend verification/finalization guards.
LIVE FONEPAY PAYMENTS ARE NOT ACTIVATED. The official account-issued API
specification, merchant adapter and UAT credentials are still required.
Pay will show a configuration error until that work is completed. Environment
placeholders alone cannot activate payments. No test QR can pay a real bill.
Cash/pending-cash billing remains available.

BACKEND DEPLOYMENT
Deploy the matching backend source and review/apply the two Fonepay migrations
through the normal controlled deployment. This ZIP does not deploy the backend
or migrate a database. See docs/FONEPAY_SETUP.md for details and limitations.
No merchant secrets, account sessions or business records are included.

CONTENTS AND VALIDATION
This is the actual lib/main.dart Windows Release application, not a test harness.
The package includes the executable, runtime/plugin DLLs and Flutter data assets.
The preceding payment implementation passed 258 Flutter tests and backend checks;
printed test PDF layouts were inspected. The local-customer fix was compile checked.
No live Fonepay UAT or physical printer
certification was performed. FILES-SHA256.txt records the packaged file hashes.
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
  foreach ($required in @('RamPrasadBilling.exe', 'flutter_windows.dll', 'data/app.so', 'README.txt', 'docs/FONEPAY_SETUP.md', 'FILES-SHA256.txt')) {
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
