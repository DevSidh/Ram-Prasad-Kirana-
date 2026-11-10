$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
$taskTemporary = Join-Path $taskProject 'tmp/android-build-temp'
New-Item -ItemType Directory -Path $taskTemporary -Force | Out-Null
$env:TEMP = (Get-Item -LiteralPath $taskTemporary).FullName
$env:TMP = $env:TEMP
Set-Location -LiteralPath $taskProject
# Do not reuse a Gradle daemon pointing at an expired editor sandbox temp path.
& (Join-Path $taskProject 'android/gradlew.bat') --stop
rtk flutter build apk --release --dart-define=API_BASE_URL=https://ram-prasad-kirana-backend.onrender.com/api/v1
exit $LASTEXITCODE
