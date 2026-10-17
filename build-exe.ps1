# Build countdown.ps1 into a single Windows .exe (requires module ps2exe).
param(
    [string]$OutputName = 'CountdownTimer.exe',
    [switch]$RefreshIcon
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host 'Installing ps2exe (CurrentUser)...'
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -Force

& (Join-Path $root 'ensure-utf8bom.ps1')

$inputFile = (Resolve-Path -LiteralPath (Join-Path $root 'countdown.ps1')).Path
$outputFile = Join-Path $root $OutputName
$iconPng = Join-Path $root 'Countdown.png'
$iconIco = Join-Path $root 'Countdown.ico'

if ($RefreshIcon -or -not (Test-Path -LiteralPath $iconIco)) {
    if (-not (Test-Path -LiteralPath $iconPng)) {
        throw "Missing icon source: $iconPng"
    }
    & (Join-Path $root 'make-icon.ps1') -Root $root
}
if (-not (Test-Path -LiteralPath $iconIco)) {
    throw "Missing $iconIco (use -RefreshIcon to build from Countdown.png)"
}

# CSC /win32icon is picky about backslashes in paths; forward slashes embed reliably.
$iconForCsc = ([System.IO.Path]::GetFullPath($iconIco) -replace '\\', '/')

Invoke-ps2exe `
    -inputFile $inputFile `
    -outputFile $outputFile `
    -sta `
    -noConsole `
    -iconFile $iconForCsc `
    -title '超声科技能大赛计时器'

Write-Host "Built: $outputFile"
Write-Host "Icon: $iconForCsc"
Write-Host 'Settings will be saved as countdown.settings.json next to the exe.'
Write-Host 'If Explorer still shows an old icon, rename the exe or log off once (icon cache).'
