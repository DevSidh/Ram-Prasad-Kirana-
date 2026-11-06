param([string]$Check = 'backend')
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Path tmp -Force | Out-Null
switch ($Check) {
  'backend' { Push-Location backend; rtk npm test *> ../tmp/admin-audit-backend.log; $result = $LASTEXITCODE; Pop-Location }
  'analyze' { rtk flutter analyze *> tmp/admin-audit-analyze.log; $result = $LASTEXITCODE }
  'flutter' { rtk flutter test --reporter expanded *> tmp/admin-audit-flutter.log; $result = $LASTEXITCODE }
  'typescript' { Push-Location backend; rtk npm run build *> ../tmp/admin-audit-typescript.log; $result = $LASTEXITCODE; Pop-Location }
}
Write-Output "$Check exit code: $result"
exit $result
