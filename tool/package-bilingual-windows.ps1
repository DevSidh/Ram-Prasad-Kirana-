$ErrorActionPreference = 'Stop'
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pubspec = Get-Content -LiteralPath (Join-Path $workspaceRoot 'pubspec.yaml') -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)')
if (-not $match.Success) { throw 'No version/build number in pubspec.yaml.' }
$version = $match.Groups[1].Value
$buildNumber = $match.Groups[2].Value
$source = Join-Path $workspaceRoot 'build/windows/x64/runner/Release'
$exe = Join-Path $source 'RamPrasadBilling.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Build the Windows release first.' }
if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne "$version+$buildNumber") {
  throw 'The executable version does not match pubspec.yaml. Rebuild first.'
}
$name = "FastStore-Windows-$version-English-Nepali"
$package = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $name))
$zip = "$package.zip"
if (-not $package.StartsWith($workspaceRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Package destination is outside the workspace.'
}
if ((Test-Path -LiteralPath $package) -or (Test-Path -LiteralPath $zip)) {
  throw 'This package already exists. Use a new version; do not merge old runtime files.'
}
New-Item -ItemType Directory -Path $package | Out-Null
Get-ChildItem -LiteralPath $source -File | Where-Object {
  $_.Extension -eq '.dll' -or $_.Name -eq 'RamPrasadBilling.exe' -or $_.Name -eq 'native_assets.json'
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $package }
Copy-Item -LiteralPath (Join-Path $source 'data') -Destination $package -Recurse
Copy-Item -LiteralPath (Join-Path $workspaceRoot 'docs/elder-friendly-billing.md') -Destination (Join-Path $package 'USER-GUIDE.md')
$readme = @"
FastStore $version+$buildNumber - Windows x64 billing

1. Extract this entire ZIP into a new folder on the billing computer.
2. Open RamPrasadBilling.exe inside that folder.
3. Keep the data folder and all DLLs beside the executable.
4. Select English or नेपाली at the top. The selected language is remembered.
5. Products > Add stock works without a supplier bill or invoice number.

Existing billing records stay in C:/Ramprasad store and the application's existing local storage.
This package contains software only; it does not replace your bills, customers or stock records.
Read USER-GUIDE.md for stock units, printing and language details.

नेपाली:
पूरै जिप फाइल नयाँ फोल्डरमा खोल्नुहोस्। त्यसभित्रको RamPrasadBilling.exe चलाउनुहोस्।
माथिबाट नेपाली भाषा छान्नुहोस्। पहिलेका बिल र ग्राहक विवरण मेटिँदैनन्।
सामानको मौज्दात थप्न आपूर्तिकर्ताको बिल चाहिँदैन।
"@
Set-Content -LiteralPath (Join-Path $package 'README.txt') -Value $readme -Encoding UTF8
$required = @('RamPrasadBilling.exe','flutter_windows.dll','printing_plugin.dll','pdfium.dll',
  'data/app.so','data/icudtl.dat','data/flutter_assets/assets/fonts/NotoSansDevanagari.ttf',
  'data/flutter_assets/assets/translations/billing_ne.json')
foreach ($relative in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $package $relative))) { throw "Required runtime file missing: $relative" }
}
$sourceCatalog = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $workspaceRoot 'assets/translations/billing_ne.json')
$bundledCatalog = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $package 'data/flutter_assets/assets/translations/billing_ne.json')
if ($sourceCatalog.Hash -ne $bundledCatalog.Hash) { throw 'The translation bundle is stale. Rebuild the release.' }
Compress-Archive -LiteralPath $package -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$zip.sha256" -Value "$hash  $name.zip" -Encoding ASCII
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
  if ($archive.Entries.Count -lt 25) { throw 'The ZIP does not contain the complete runtime.' }
  $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
  if (-not ($entryNames -contains "$name/RamPrasadBilling.exe")) { throw 'ZIP executable missing.' }
  Write-Output "ZIP entries: $($archive.Entries.Count)"
} finally { $archive.Dispose() }
Write-Output "ZIP: $zip"
Write-Output "Bytes: $((Get-Item -LiteralPath $zip).Length)"
Write-Output "SHA256: $hash"
