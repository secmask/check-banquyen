function Get-CLOfficeToolPath {
    [CmdletBinding()]
    param([string]$FileName)

    $officeVersions = 'Office16', 'Office15', 'Office14', 'Office12'
    $baseRoots = @(
        "$env:ProgramFiles\Microsoft Office\root",
        "${env:ProgramFiles(x86)}\Microsoft Office\root",
        "$env:ProgramFiles\Microsoft Office",
        "${env:ProgramFiles(x86)}\Microsoft Office"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $roots = foreach ($base in $baseRoots) {
        foreach ($version in $officeVersions) { Join-Path $base $version }
    }

    foreach ($root in $roots) {
        $candidate = Join-Path $root $FileName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
}

function Split-CLOsppProducts {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $blocks = @($Text -split '(?im)(?=^LICENSE NAME:)') | Where-Object { $_ -match '(?im)^LICENSE NAME:' }
    if ($blocks.Count -eq 0) { $blocks = @($Text) }
    $blocks
}

function Convert-CLLastFive {
    param([string]$Text)
    if ($Text -match '(?i)(last 5 characters[^:]*:\s*|Last 5 characters of installed product key:\s*)([A-Z0-9]{5})') { return $matches[2] }
    if ($Text -match '(?i)PartialProductKey\s*[:=]\s*([A-Z0-9]{5})') { return $matches[1] }
    return $null
}

function Convert-CLOfficeProductName {
    param([string]$ReleaseId)

    if ([string]::IsNullOrWhiteSpace($ReleaseId)) { return 'Microsoft Office' }

    $name = $ReleaseId -replace '(?i)Retail$', ' Retail'
    $name = $name -replace '(?i)Volume$', ' Volume'
    $name = $name -replace '(?i)(Home)(Student)', '$1 and $2 '
    $name = $name -replace '(?i)(Home)(Business)', '$1 and $2 '
    $name = $name -replace '(?i)(Professional)(Plus)', '$1 $2 '
    $name = $name -replace '(?i)(O365)(ProPlus)', 'Microsoft 365 Apps for enterprise '
    $name = $name -replace '(\d{4})', ' $1'
    $name = $name -replace '\s+', ' '
    "Microsoft Office $($name.Trim())"
}

function Get-CLOfficeClickToRunLicense {
    [CmdletBinding()]
    param()

    $configPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration'
    )
    $licensingNextPath = 'HKCU:\Software\Microsoft\Office\16.0\Common\Licensing\LicensingNext'

    foreach ($configPath in $configPaths) {
        if (-not (Test-Path -LiteralPath $configPath)) { continue }

        $config = Get-ItemProperty -LiteralPath $configPath -ErrorAction SilentlyContinue
        if (-not $config) { continue }

        $releaseIds = @()
        if ($config.ProductReleaseIds) {
            $releaseIds = @($config.ProductReleaseIds -split ',') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
        }
        if (-not $releaseIds) {
            $releaseIds = @(
                $config.PSObject.Properties.Name |
                Where-Object { $_ -match '^[A-Za-z0-9]+(?:Retail|Volume)\.' } |
                ForEach-Object { ($_ -split '\.')[0] } |
                Select-Object -Unique
            )
        }

        $licenseProps = @{}
        if (Test-Path -LiteralPath $licensingNextPath) {
            $licensingNext = Get-ItemProperty -LiteralPath $licensingNextPath -ErrorAction SilentlyContinue
            foreach ($prop in @($licensingNext.PSObject.Properties)) {
                if ($prop.Name -notmatch '^PS') { $licenseProps[$prop.Name.ToLowerInvariant()] = $prop.Value }
            }
        }

        $items = foreach ($releaseId in $releaseIds) {
            $readyProp = "$releaseId.OSPPReady"
            $osppReady = $config.PSObject.Properties[$readyProp].Value
            $licenseValue = $licenseProps[$releaseId.ToLowerInvariant()]
            $isLicensed = ($osppReady -eq 1) -or ($licenseValue -eq 2)

            [pscustomobject]@{
                Source            = 'ClickToRun registry'
                ToolPath          = $configPath
                ProductName       = Convert-CLOfficeProductName -ReleaseId $releaseId
                LicenseStatusText = if ($isLicensed) { 'Licensed' } elseif ($releaseId) { 'Installed - status unknown' } else { 'Unknown' }
                PartialProductKey = $null
                RawSummary        = "ReleaseId=$releaseId; Version=$($config.VersionToReport); Platform=$($config.Platform); OSPPReady=$osppReady; LicensingNext=$licenseValue; Channel=$($config.AudienceData)"
                IsLicensed        = [bool]$isLicensed
            }
        }

        if ($items) { return @($items) }
    }

    return @()
}

function Get-CLOfficeLicense {
    [CmdletBinding()]
    param()

    $clickToRun = @(Get-CLOfficeClickToRunLicense)
    if ($clickToRun.Count -gt 0 -and @($clickToRun | Where-Object { $_.IsLicensed }).Count -gt 0) { return $clickToRun }

    $vnext = Get-CLOfficeToolPath -FileName 'vnextdiag.ps1'
    if ($vnext) {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $vnext -action list 2>&1 | Out-String
        $isLicensed = $output -match '(?i)licensed|activated'
        $vnextResult = [pscustomobject]@{
            Source            = 'vnextdiag.ps1'
            ToolPath          = $vnext
            ProductName       = 'Microsoft 365 Apps / vNext'
            LicenseStatusText = if ($output -match '(?i)licensed|activated') { 'Licensed' } elseif ($output -match '(?i)unlicensed|not activated') { 'Unlicensed' } else { 'Unknown' }
            PartialProductKey = Convert-CLLastFive -Text $output
            RawSummary        = ($output -split "`r?`n" | Where-Object { $_ -match '(?i)license|activation|product|subscription|partial|last 5' } | Select-Object -First 25) -join '; '
            IsLicensed        = $isLicensed
        }

        if ($isLicensed -or $clickToRun.Count -eq 0) { return $vnextResult }
    }

    $ospp = Get-CLOfficeToolPath -FileName 'OSPP.VBS'
    if ($ospp) {
        $output = & cscript.exe //nologo $ospp /dstatus 2>&1 | Out-String
        $products = foreach ($block in @(Split-CLOsppProducts -Text $output)) {
            [pscustomobject]@{
                Source            = 'ospp.vbs'
                ToolPath          = $ospp
                ProductName       = if ($block -match '(?im)^LICENSE NAME:\s*(.+)$') { $matches[1].Trim() } else { 'Microsoft Office' }
                LicenseStatusText = if ($block -match '(?i)LICENSE STATUS:\s*---LICENSED---') { 'Licensed' } elseif ($block -match '(?i)LICENSE STATUS:') { 'Activation Issue' } else { 'Unknown' }
                PartialProductKey = Convert-CLLastFive -Text $block
                RawSummary        = ($block -split "`r?`n" | Where-Object { $_ -match '(?i)license|product key|sku|remaining|error code' } | Select-Object -First 25) -join '; '
                IsLicensed        = $block -match '(?i)LICENSE STATUS:\s*---LICENSED---'
            }
        }

        if ($products.Count -gt 0) { return @($products) }
    }

    if ($clickToRun.Count -gt 0) { return $clickToRun }

    [pscustomobject]@{
        Source            = 'NotFound'
        ToolPath          = $null
        ProductName       = $null
        LicenseStatusText = 'Not Detected'
        PartialProductKey = $null
        RawSummary        = 'No supported Office licensing diagnostic tool was found.'
        IsLicensed        = $false
    }
}

Export-ModuleMember -Function Get-CLOfficeLicense