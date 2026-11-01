[CmdletBinding()]
param(
    [ValidateSet('apk', 'windows', 'linux')]
    [string]$Target = 'windows',
    [ValidateSet('debug', 'release', 'profile')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
$appRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $appRoot
try {
    $arguments = @('build', $Target)
    if ($Mode -eq 'debug') { $arguments += '--debug' }
    elseif ($Mode -eq 'profile') { $arguments += '--profile' }
    else { $arguments += '--release' }
    flutter @arguments
}
finally {
    Pop-Location
}
