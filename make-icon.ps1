# Build Countdown.ico from Countdown.png (optional; prefer keeping hand-tuned Countdown.ico).
param(
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$py = Join-Path $Root 'make-icon.py'
if (-not (Test-Path -LiteralPath $py)) {
    throw "Missing $py"
}
& python $py
