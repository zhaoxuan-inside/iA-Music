# iA-Music 打包入口（Android arm64-v8a 交付标准；docs/ARCHITECTURE.md「构建链」）。
# 用法：powershell -File packaging/build.ps1
# 产物：dist/iA-Music-v<版本>-arm64-v8a.apk（+ .sha256 校验）
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# 版本号以 pubspec.yaml 的 version: x.y.z+n 为准（n = versionCode 基数；
# split-per-abi 下 arm64 包的实际 versionCode = n*1000 + 2）。
$pubspec = Get-Content -Path 'pubspec.yaml' -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)')
if (-not $m.Success) { throw 'pubspec.yaml 缺少 version 字段' }
$versionName = $m.Groups[1].Value
$buildNo = $m.Groups[2].Value

Write-Host "版本: v$versionName (build $buildNo → arm64 versionCode $([long]$buildNo * 1000 + 2))"

# v8a 交付标准：split-per-abi（不带 split 的 universal 包会混入三套 ABI 插件库）。
flutter build apk --release --split-per-abi --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
if (-not (Test-Path $src)) { throw "未找到构建产物：$src" }
$outDir = 'dist'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$name = "iA-Music-v$versionName-arm64-v8a.apk"
$out = Join-Path $outDir $name
Copy-Item $src $out -Force

# SHA-256 校验文件（发布件完整性自证）。
$hash = (Get-FileHash -Path $out -Algorithm SHA256).Hash.ToLower()
"$hash  $name" | Set-Content -Path "$out.sha256" -Encoding ascii

$size = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host "`n产物: $out ($size MB)"
Write-Host "SHA-256: $hash"
