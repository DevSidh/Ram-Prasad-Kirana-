New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot '../tmp') | Out-Null
rtk flutter test --reporter expanded *> tmp/bilingual-test.log
exit $LASTEXITCODE
