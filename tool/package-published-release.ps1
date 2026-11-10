param([string]$Version = '3.3.4')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version' }
$taskProject = Split-Path -Parent $PSScriptRoot
$taskSource = Join-Path $taskProject 'build/windows/x64/runner/Release'
$taskName = "FastStore-Windows-$Version"
$taskDestination = Join-Path $taskProject $taskName
$taskZip = "$taskDestination.zip"
if ((Test-Path -LiteralPath $taskDestination) -or (Test-Path -LiteralPath $taskZip)) { throw 'Package already exists; inspect before replacing.' }
foreach ($required in @('RamPrasadBilling.exe','flutter_windows.dll','data/app.so','data/icudtl.dat')) {
  if (!(Test-Path -LiteralPath (Join-Path $taskSource $required))) { throw "Missing release component: $required" }
}
New-Item -ItemType Directory -Path $taskDestination | Out-Null
Copy-Item -Path "$taskSource/*" -Destination $taskDestination -Recurse
Copy-Item -LiteralPath (Join-Path $taskProject "RELEASE_NOTES_$Version.md") -Destination $taskDestination
@'
Close FastStore. Extract this complete ZIP into a new folder, then open RamPrasadBilling.exe.
Keep all DLLs and the data folder beside the executable. Do not copy only the EXE.
Preserve C:\Ramprasad store and all existing business records.
Sign in as an administrator to use Product Excel. Edit Price NPR, then save and close Excel.
The workbook and receipt PDFs are saved under C:\Ramprasad store\bills.
See the included release notes for verification limits and backend requirements.
'@ | Set-Content -LiteralPath (Join-Path $taskDestination 'INSTALL.txt') -Encoding UTF8
Compress-Archive -LiteralPath $taskDestination -DestinationPath $taskZip -CompressionLevel Optimal
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskArchive = [IO.Compression.ZipFile]::OpenRead($taskZip)
try {
  foreach ($suffix in @('/RamPrasadBilling.exe','/flutter_windows.dll','/data/app.so','/data/icudtl.dat')) {
    if (!($taskArchive.Entries | Where-Object { $_.FullName.Replace('\','/').EndsWith($suffix) })) { throw "Missing packaged file: $suffix" }
  }
} finally { $taskArchive.Dispose() }
Get-Item -LiteralPath $taskZip | Select-Object FullName,Length
Get-FileHash -LiteralPath $taskZip -Algorithm SHA256
