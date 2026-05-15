function New-CLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Data,
        [string]$OutputDirectory = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'CheckLicense'),
        [switch]$NoReport
    )

    if ($NoReport) { return $null }

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $OutputDirectory "check-license-$stamp.json"

    $Data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    [pscustomobject]@{ JsonPath = $jsonPath; Directory = $OutputDirectory }
}

Export-ModuleMember -Function New-CLReport