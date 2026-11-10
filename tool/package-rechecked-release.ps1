param([string]$Name = 'FastStore-Windows-3.3.3-Rechecked-20261110')
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($Name -notmatch '^[A-Za-z0-9.-]+$') { throw 'Invalid package name' }
$source = Join-Path $workspace 'build/windows/x64/runner/Release'
$destination = Join-Path $workspace $Name
$archive = "$destination.zip"
if ((Test-Path $destination) -or (Test-Path $archive)) { throw 'Package already exists' }
if (!(Test-Path (Join-Path $source 'RamPrasadBilling.exe'))) { throw 'Build Windows first' }
New-Item -ItemType Directory -Path $destination | Out-Null
Copy-Item -Path "$source/*" -Destination $destination -Recurse
Copy-Item -LiteralPath (Join-Path $workspace 'AUDIT_REPORT.md') -Destination $destination
@'
Close FastStore. Extract this complete folder to a new location and run RamPrasadBilling.exe.
Keep the DLL files and data folder beside the executable.
Do not delete C:\Ramprasad store or uninstall the existing app to replace this portable folder.
Choose your receipt printer in the app before printing.
See AUDIT_REPORT.md for verified checks and physical-device checks still needed.
'@ | Set-Content -LiteralPath (Join-Path $destination 'INSTALL.txt') -Encoding UTF8
Compress-Archive -LiteralPath $destination -DestinationPath $archive -CompressionLevel Optimal
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
  foreach ($suffix in @('/RamPrasadBilling.exe', '/flutter_windows.dll', '/data/icudtl.dat')) {
    if (!($zip.Entries | Where-Object { $_.FullName.Replace('\','/').EndsWith($suffix) })) {
      throw "Missing release file: $suffix"
    }
  }
} finally { $zip.Dispose() }
Get-FileHash -LiteralPath $archive -Algorithm SHA256
Get-Item -LiteralPath $archive | Select-Object FullName, Length
