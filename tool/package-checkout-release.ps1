$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$source = Join-Path $workspace 'build\windows\x64\runner\Release'
$name = 'FastStore-Windows-3.3.1-Final-Checked-20261107'
$destination = Join-Path $workspace $name
$zip = "$destination.zip"
if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $zip)) { throw 'Refusing to replace an existing release.' }
$exe = Join-Path $source 'RamPrasadBilling.exe'
if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne '3.3.1+27') { throw 'Wrong executable version.' }
$compiled = Get-Item -LiteralPath (Join-Path $source 'data\app.so')
$latest = Get-ChildItem -LiteralPath (Join-Path $workspace 'lib') -Recurse -File -Filter '*.dart' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($compiled.LastWriteTimeUtc -lt $latest.LastWriteTimeUtc) { throw 'Rebuild after the latest source edits.' }
$assets = @('assets\translations\billing_ne.json', 'assets\images\business_esewa_qr.jpeg',
  'assets\fonts\NotoSansMono-Regular.ttf', 'assets\fonts\OFL-NotoSansMono.txt', 'assets\fonts\NotoSansDevanagari.ttf')
foreach ($asset in $assets) {
  if ((Get-FileHash -LiteralPath (Join-Path $source "data\flutter_assets\$asset")).Hash -ne
      (Get-FileHash -LiteralPath (Join-Path $workspace $asset)).Hash) { throw "Stale asset: $asset" }
}
New-Item -ItemType Directory -Path $destination | Out-Null
Get-ChildItem -LiteralPath $source -File | Where-Object {
  $_.Extension -eq '.dll' -or $_.Name -in @('RamPrasadBilling.exe', 'native_assets.json')
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination }
Copy-Item -LiteralPath (Join-Path $source 'data') -Destination $destination -Recurse
$runtime = @(Get-ChildItem -LiteralPath $destination -Recurse -File)
foreach ($file in $runtime) {
  $relative = $file.FullName.Substring($destination.Length + 1)
  if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $source $relative)).Hash) { throw "Copy mismatch: $relative" }
}
foreach ($required in @('RamPrasadBilling.exe', 'flutter_windows.dll', 'printing_plugin.dll', 'pdfium.dll', 'data\app.so', 'data\icudtl.dat')) {
  if (!(Test-Path -LiteralPath (Join-Path $destination $required))) { throw "Missing runtime: $required" }
}
$guide = Get-Content -LiteralPath (Join-Path $workspace 'docs\checkout-printing-3.3.1.md') -Raw
Set-Content -LiteralPath (Join-Path $destination 'RELEASE-AND-SETUP.md') -Value (($guide -split '## Main modified source')[0]) -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $workspace 'docs\room-inventory.md') -Destination (Join-Path $destination 'INVENTORY-GUIDE.md')
$recovery = Get-Content -LiteralPath (Join-Path $workspace 'docs\sign-in-database-recovery.md') -Raw
Set-Content -LiteralPath (Join-Path $destination 'SIGN-IN-RECOVERY.md') -Value (($recovery -split '## Code changes and validation')[0]) -Encoding UTF8
$samples = Join-Path $destination 'Receipt samples'
New-Item -ItemType Directory -Path $samples | Out-Null
Get-ChildItem -LiteralPath (Join-Path $workspace 'tmp\pdfs') -Filter 'receipt-*.pdf' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $samples }
$readme = @'
FASTSTORE 3.3.1+27 - WINDOWS BILLING

1. Close the old app. Keep its folder as a backup.
2. Extract this ZIP completely into a NEW folder on the billing computer.
3. Open RamPrasadBilling.exe. Keep all DLLs and the data folder together.
4. Receipt & printer settings: choose 58 mm and Deli ES301.
5. Preserve C:\Ramprasad store and existing app preferences. This ZIP contains
   software and sample receipts, not your business records.

Read RELEASE-AND-SETUP.md before use. The new backend code and migration must
be deployed for online price-edited checkout and catalogue price synchronization.
Computer-only price changes remain local and queued until that deployment.
If sign-in is unavailable, read SIGN-IN-RECOVERY.md. The provider's exhausted
database usage limit must be restored in CockroachDB; reinstalling cannot fix it.
Do not change Windows security settings. Physical USB printing must be checked
on the billing computer. Samples are fictitious, not completed business sales.
'@
Set-Content -LiteralPath (Join-Path $destination 'READ-ME-FIRST.txt') -Value $readme -Encoding UTF8
if (Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object {
  $_.Name -in @('.env', 'shared_preferences.json', 'flutter_secure_storage.dat', 'customers.json', 'database-snapshot.json') -or $_.Extension -in @('.csv', '.xlsx', '.jks')
}) { throw 'Private records or credentials in package.' }
$manifest = Get-ChildItem -LiteralPath $destination -File -Recurse | Sort-Object FullName | ForEach-Object {
  $relative = $_.FullName.Substring($destination.Length + 1).Replace('\','/')
  "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
}
Set-Content -LiteralPath (Join-Path $destination 'FILES-SHA256.txt') -Value $manifest -Encoding ASCII
Compress-Archive -LiteralPath $destination -DestinationPath $zip -CompressionLevel Optimal
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
  $files = @(Get-ChildItem -LiteralPath $destination -File -Recurse)
  $entries = @($archive.Entries | Where-Object { $_.Name })
  if ($files.Count -ne $entries.Count) { throw 'ZIP file count mismatch.' }
  foreach ($entry in $entries) {
    $relative = $entry.FullName.Replace('\','/').Substring($name.Length + 1)
    $path = Join-Path $destination $relative
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($hash -ne (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash) { throw "ZIP hash mismatch: $relative" }
  }
} finally { $archive.Dispose() }
$zipInfo = Get-Item -LiteralPath $zip
Write-Output "Folder: $destination"
Write-Output "ZIP: $zip ($([Math]::Round($zipInfo.Length / 1MB, 2)) MiB)"
Write-Output "Verified files: $($files.Count)"
Get-FileHash -LiteralPath $zip -Algorithm SHA256 | Format-List
