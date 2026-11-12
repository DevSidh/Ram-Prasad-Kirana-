param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($Source)

function Read-Entry([string]$name) {
  $entry = $archive.GetEntry($name)
  if (!$entry) { return $null }
  $reader = [IO.StreamReader]::new($entry.Open())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

try {
  $strings = @()
  $shared = Read-Entry 'xl/sharedStrings.xml'
  if ($shared) {
    [xml]$document = $shared
    $strings = @($document.SelectNodes('//*[local-name()="si"]') | ForEach-Object {
      ($_.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join ''
    })
  }
  $sheets = @()
  foreach ($entry in $archive.Entries | Where-Object { $_.FullName -match '^xl/worksheets/sheet\d+\.xml$' }) {
    [xml]$sheet = Read-Entry $entry.FullName
    $rows = @($sheet.SelectNodes('//*[local-name()="sheetData"]/*[local-name()="row"]') | ForEach-Object {
      $row = $_
      $cells = [ordered]@{}
      foreach ($cell in $row.SelectNodes('./*[local-name()="c"]')) {
        $value = [string]$cell.SelectSingleNode('./*[local-name()="v"]').InnerText
        if ($cell.t -eq 's') { $value = $strings[[int]$value] }
        if ($cell.t -eq 'inlineStr') { $value = ($cell.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '' }
        $cells[[string]$cell.r] = $value
      }
      [PSCustomObject]@{ row = [int]$row.r; cells = $cells }
    })
    $sheets += [PSCustomObject]@{ file = $entry.FullName; rows = $rows }
  }
  $sheets | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Output -Encoding UTF8
} finally {
  $archive.Dispose()
}
