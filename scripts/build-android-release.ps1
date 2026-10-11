param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [ValidateSet('appbundle', 'apk')]
    [string]$Artifact = 'appbundle',

    [switch]$ApplyMigrations
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$signingProperties = Join-Path $projectRoot 'android\key.properties'

$apiUri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri) -or
    $apiUri.Scheme -ne 'https' -or
    $apiUri.Host -match '(^localhost$|\.invalid$|\.test$|\.example$|\.localhost$)' -or
    $ApiBaseUrl -match 'YOUR-API-HOST|example\.com' -or
    $apiUri.AbsolutePath.TrimEnd('/') -notmatch '/api/v1$') {
    throw 'ApiBaseUrl must be a deployed HTTPS URL ending in /api/v1.'
}

if (-not (Test-Path -LiteralPath $signingProperties -PathType Leaf)) {
    throw 'Android release signing is not configured. Add android/key.properties and its upload keystore before building.'
}

$signing = @{}
Get-Content -LiteralPath $signingProperties | ForEach-Object {
    if ($_ -match '^\s*([^#!\s][^=]*)\s*=\s*(.*?)\s*$') {
        $signing[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}
foreach ($key in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
    if ([string]::IsNullOrWhiteSpace($signing[$key])) {
        throw "Android signing configuration is missing '$key' in android/key.properties."
    }
}

$keyStorePath = $signing['storeFile']
if (-not [System.IO.Path]::IsPathRooted($keyStorePath)) {
    $keyStorePath = Join-Path (Join-Path $projectRoot 'android\app') $keyStorePath
}
if (-not (Test-Path -LiteralPath $keyStorePath -PathType Leaf)) {
    throw 'The Android upload keystore configured by storeFile could not be found.'
}

Push-Location $backendRoot
try {
    & .\node_modules\.bin\prisma.cmd validate --schema prisma\schema.prisma
    if ($LASTEXITCODE -ne 0) { throw 'Prisma schema validation failed.' }

    & .\node_modules\.bin\prisma.cmd generate --schema prisma\schema.prisma
    if ($LASTEXITCODE -ne 0) { throw 'Prisma client generation failed.' }

    & npm.cmd run build
    if ($LASTEXITCODE -ne 0) { throw 'Backend production build failed.' }

    & npm.cmd test
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed.' }
}
finally {
    Pop-Location
}

Push-Location $projectRoot
try {
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }

    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }

    & flutter build $Artifact --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
}
finally {
    Pop-Location
}

Push-Location $backendRoot
try {
    if ($ApplyMigrations) {
        & .\node_modules\.bin\prisma.cmd migrate deploy --schema prisma\schema.prisma
        if ($LASTEXITCODE -ne 0) { throw 'CockroachDB migrations did not complete.' }
    }
    else {
        & .\node_modules\.bin\prisma.cmd migrate status --schema prisma\schema.prisma
        if ($LASTEXITCODE -ne 0) {
            throw 'Database migration status check failed. Resolve pending migrations deliberately, or rerun with -ApplyMigrations after confirming a current backup.'
        }
    }
}
finally {
    Pop-Location
}
