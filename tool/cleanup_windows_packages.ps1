param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$currentName = 'FastStore-Windows-3.2.0-Customers-Ledger-20261105'
$currentZip = Join-Path $workspace "$currentName.zip"
if (!(Test-Path -LiteralPath $currentZip)) { throw 'Create the new release ZIP before removing old packages.' }
$actual = (Get-FileHash -LiteralPath $currentZip -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = (Get-Content -LiteralPath "$currentZip.sha256" -Raw).Split(' ')[0].Trim()
if ($actual -ne $expected) { throw 'New release checksum mismatch.' }
$targets = @(Get-ChildItem -LiteralPath $workspace -Force | Where-Object {
  $_.Name -match '^(FastStore-Windows-3\.1\.[45](?:[.-].*)?|FastStore-Windows-3\.2\.0-(?:QR-Fix-)?20261105(?:\.zip(?:\.sha256)?)?|Ram-Prasad-General-Store-Windows-3\.0\.[45](?:[.-].*)?|RamPrasadStore-Windows-x64(?:\.zip(?:\.sha256)?)?|Final Windows Version)$'
})
foreach ($item in $targets) {
  $resolved = [IO.Path]::GetFullPath($item.FullName)
  if ([IO.Path]::GetDirectoryName($resolved) -ne $workspace) { throw "Outside workspace: $resolved" }
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked target: $resolved" }
  if ($item.PSIsContainer) {
    $running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and $_.Path.StartsWith($resolved + '\', [StringComparison]::OrdinalIgnoreCase) } catch { $false }
    }
    if ($running) { throw "Close the application running from $resolved before removing its package." }
    $children = @(Get-ChildItem -LiteralPath $resolved -Force)
    if (!($children | Where-Object { $_.Name -in @('RamPrasadBilling.exe','RamPrasadStore.exe','data') })) { throw "Not a release folder: $resolved" }
    foreach ($child in $children) {
      if ($child.PSIsContainer -and $child.Name -notin @('data','docs')) { throw "Unexpected folder: $($child.FullName)" }
      if (!$child.PSIsContainer -and $child.Extension -notin @('.exe','.dll','.lib','.exp','.json','.txt','.md')) { throw "Unexpected file: $($child.FullName)" }
    }
    if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Linked content in $resolved" }
  } elseif ($item.Name -notmatch '\.zip(?:\.sha256)?$') { throw "Not a release archive: $resolved" }
}
$bytes = ($targets | ForEach-Object {
  if ($_.PSIsContainer) { (Get-ChildItem -LiteralPath $_.FullName -File -Recurse | Measure-Object Length -Sum).Sum } else { $_.Length }
} | Measure-Object -Sum).Sum
$targets | Select-Object Name
if ($Apply) {
  foreach ($item in $targets) { Remove-Item -LiteralPath $item.FullName -Recurse -Force }
}
[PSCustomObject]@{ Applied = [bool]$Apply; Items = $targets.Count; ReclaimedMB = [Math]::Round($bytes / 1MB, 2); Kept = $currentZip } | Format-List
