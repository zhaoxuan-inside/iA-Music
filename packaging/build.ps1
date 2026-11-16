# iA-Music 打包入口（Android 全 ABI：arm64-v8a / armeabi-v7a / x86_64）
# 用法：powershell -File packaging/build.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# 版本号以 pubspec.yaml 的 version: x.y.z+n 为准（n = versionCode）
$pubspec = Get-Content -Path 'pubspec.yaml' -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)')
if (-not $m.Success) { throw 'pubspec.yaml 缺少 version 字段' }
$versionName = $m.Groups[1].Value

Write-Host "版本: v$versionName"

# 全功能通用包：播放引擎为 AndroidX Media3/ExoPlayer，无 mpv；
# 不再按 ABI 裁剪，模拟器与真机使用同一个包。
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = 'build\app\outputs\flutter-apk\app-release.apk'
$outDir = 'dist'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir "iA-Music-v$versionName-universal.apk"
Copy-Item $src $out -Force

Write-Host "`n产物: $out"
