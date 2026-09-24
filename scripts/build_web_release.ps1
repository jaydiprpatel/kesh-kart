param(
  [ValidateSet('customer', 'barber')]
  [string]$Portal = 'customer'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appRoot = Split-Path -Parent $PSScriptRoot
$platformRoot = Split-Path -Parent $appRoot

Push-Location $appRoot
try {
  flutter build web --release --no-web-resources-cdn "--dart-define=KESHKART_WEB_PORTAL=$Portal"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  node "$platformRoot\scripts\cache_bust_flutter_web.js" "$appRoot\build\web"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}