# Ensures countdown.ps1 is UTF-8 with BOM (Windows PowerShell 5.1)
$path = Join-Path $PSScriptRoot 'countdown.ps1'
if (-not (Test-Path -LiteralPath $path)) { exit 1 }
$utf8Read = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$text = [System.IO.File]::ReadAllText($path, $utf8Read)
[System.IO.File]::WriteAllText($path, $text, $utf8Bom)
