[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+$')]
    [int]$BuildNumber,

    [string]$BuildName = '1.0.0'
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidRoot = Join-Path $projectRoot 'android'
$propertiesPath = Join-Path $androidRoot 'key.properties'

if (-not (Test-Path -LiteralPath $propertiesPath -PathType Leaf)) {
    throw "Release signing is missing. Copy android/key.properties.example to android/key.properties and use the existing Google Play upload keystore."
}

$properties = @{}
foreach ($line in Get-Content -LiteralPath $propertiesPath) {
    if ($line -match '^\s*([^#;][^=]*)\s*=\s*(.*?)\s*$') {
        $properties[$matches[1].Trim()] = $matches[2].Trim()
    }
}

foreach ($name in 'storePassword', 'keyPassword', 'keyAlias', 'storeFile') {
    if ([string]::IsNullOrWhiteSpace($properties[$name])) {
        throw "Release signing is invalid: '$name' is missing from android/key.properties."
    }
}

$keystorePath = Join-Path $androidRoot $properties.storeFile
if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
    throw "Release signing is invalid: upload keystore not found at '$keystorePath'."
}

Push-Location $projectRoot
try {
    flutter build appbundle --release "--build-name=$BuildName" "--build-number=$BuildNumber"
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter failed to build the signed Android App Bundle."
    }

    $bundlePath = Join-Path $projectRoot 'build/app/outputs/bundle/release/app-release.aab'
    if (-not (Test-Path -LiteralPath $bundlePath -PathType Leaf)) {
        throw "Flutter reported success but no release AAB was found."
    }

    $bundle = Get-Item -LiteralPath $bundlePath
    $hash = Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256
    Write-Host "Signed KeshKart Barber AAB ready: $($bundle.FullName)"
    Write-Host "Size: $($bundle.Length) bytes"
    Write-Host "SHA256: $($hash.Hash)"
}
finally {
    Pop-Location
}
