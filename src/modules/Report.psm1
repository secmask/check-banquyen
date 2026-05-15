function New-CLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Data,
        [string]$OutputDirectory = (Join-Path $env:ProgramData 'CheckLicense\reports'),
        [switch]$NoReport
    )

    if ($NoReport) { return $null }

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $OutputDirectory "check-license-$stamp.json"
    $csvPath = Join-Path $OutputDirectory "check-license-$stamp.csv"

    $Data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $rows = @()
    foreach ($w in @($Data.WindowsLicenses)) { $rows += [pscustomobject]@{ Section='Windows'; Name=$w.ProductName; Status=$w.LicenseStatusText; Detail=$w.Description } }
    foreach ($o in @($Data.OfficeLicenses)) { $rows += [pscustomobject]@{ Section='Office'; Name=$o.ProductName; Status=$o.LicenseStatusText; Detail=$o.Source } }
    foreach ($k in @($Data.KmsInfo)) { $rows += [pscustomobject]@{ Section='KMS'; Name=$k.KeyManagementServiceName; Status=if($k.IsSuspicious){'Suspicious'}else{'Configured'}; Detail=$k.RegistryPath } }
    foreach ($i in @($Data.Indicators)) { $rows += [pscustomobject]@{ Section='Indicator'; Name=$i.Name; Status='Found'; Detail=$i.Location } }
    $rows += [pscustomobject]@{ Section='Risk'; Name=$Data.Risk.Category; Status=$Data.Risk.Level; Detail=($Data.Risk.Reasons -join '; ') }
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    [pscustomobject]@{ JsonPath = $jsonPath; CsvPath = $csvPath }
}

Export-ModuleMember -Function New-CLReport