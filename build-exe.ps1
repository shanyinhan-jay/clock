# Build countdown.ps1 into a single Windows .exe (requires module ps2exe).
param(
    [string]$OutputName = 'CountdownTimer.exe'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host 'Installing ps2exe (CurrentUser)...'
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -Force

& (Join-Path $root 'ensure-utf8bom.ps1')

$inputFile = Join-Path $root 'countdown.ps1'
$outputFile = Join-Path $root $OutputName
$iconPng = Join-Path $root 'Countdown.png'
$iconIco = Join-Path $root 'Countdown.ico'

if (-not (Test-Path -LiteralPath $iconPng)) {
    throw "Missing icon source: $iconPng"
}
python (Join-Path $root 'make-icon.py')
if (-not (Test-Path -LiteralPath $iconIco)) {
    throw "Failed to create $iconIco (need Python Pillow: pip install pillow)"
}

Invoke-ps2exe `
    -inputFile $inputFile `
    -outputFile $outputFile `
    -sta `
    -noConsole `
    -iconFile $iconIco `
    -title '超声科技能大赛计时器'

Write-Host "Built: $outputFile"
Write-Host 'Settings will be saved as countdown.settings.json next to the exe.'
