# iA-Music v2 打包入口
# 用法：
#   powershell -File packaging/build.ps1 -Target windows
#   powershell -File packaging/build.ps1 -Target android
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('windows', 'android')]
    [string]$Target
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if ($Target -eq 'windows') {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "`n产物: build\windows\x64\runner\Release\ia_music.exe"
}
else {
    # Android 仅分发 arm64（packaging/mpv 只内置 arm64 运行库）
    flutter build apk --release --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "`n产物: build\app\outputs\flutter-apk\app-release.apk"
}
