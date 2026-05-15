[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'check-license.zip')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$items = @('install.ps1', 'Check-License.cmd', 'src', 'README.md')
$existing = $items | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path -LiteralPath $_ }

if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
Compress-Archive -Path $existing -DestinationPath $OutputPath -Force
Write-Host "Created $OutputPath"