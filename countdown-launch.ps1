param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

& (Join-Path $root 'ensure-utf8bom.ps1')
& (Join-Path $root 'countdown.ps1') @RemainingArgs
exit $LASTEXITCODE
