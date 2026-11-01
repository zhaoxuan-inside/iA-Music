param(
  [string]$OutputDirectory = (Join-Path (Get-Location) 'output/android/arm64-v8a')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  flutter build apk --release --target-platform android-arm64
  $apk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
  if (!(Test-Path $apk)) {
    throw "Flutter build completed without producing $apk"
  }
  New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
  $target = Join-Path $OutputDirectory 'ia-music-arm64-v8a-release.apk'
  Copy-Item $apk $target -Force
  Write-Output $target
} finally {
  Pop-Location
}
