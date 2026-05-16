function Expand-CLAdvancedPath {
    param([string]$Path)
    [Environment]::ExpandEnvironmentVariables($Path)
}

function New-CLAdvancedIndicator {
    param(
        [string]$Type,
        [string]$Name,
        [string]$Location,
        [string]$Evidence,
        [string]$Severity = 'High'
    )

    [pscustomobject]@{
        Type = $Type
        Name = $Name
        Location = $Location
        Evidence = $Evidence
        Severity = $Severity
        IsSuspicious = $true
    }
}

function Get-CLFileSha256 {
    param([string]$Path)

    try { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() }
    catch { $null }
}

function Get-CLSignatureSummary {
    param([string]$Path)

    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        $subject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
        [pscustomobject]@{
            Status = [string]$signature.Status
            Subject = $subject
            IsMicrosoft = ($signature.Status -eq 'Valid' -and $subject -match 'Microsoft')
        }
    }
    catch {
        [pscustomobject]@{
            Status = 'Unknown'
            Subject = $null
            IsMicrosoft = $false
        }
    }
}

function Get-CLOfficeHookIndicators {
    param(
        [string[]]$OfficeSearchRoots,
        [string[]]$OfficeHookFileNames,
        [string[]]$KnownOhookSha256
    )

    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $knownHashes = @($KnownOhookSha256 | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })

    foreach ($rootRule in @($OfficeSearchRoots)) {
        $root = Expand-CLAdvancedPath -Path $rootRule
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $candidates = foreach ($fileName in @($OfficeHookFileNames)) {
            Get-ChildItem -LiteralPath $root -Filter $fileName -File -Recurse -ErrorAction SilentlyContinue
        }

        foreach ($candidateItem in @($candidates)) {
            $candidate = $candidateItem.FullName
            if (-not $seen.Add($candidate.ToLowerInvariant())) { continue }

            $hash = Get-CLFileSha256 -Path $candidate
            $signature = Get-CLSignatureSummary -Path $candidate
            $hashMatched = $hash -and ($knownHashes -contains $hash)
            $severity = if ($hashMatched -or -not $signature.IsMicrosoft) { 'High' } else { 'Medium' }
            $evidence = "Office loads local $($candidateItem.Name); SHA256=$hash; Signature=$($signature.Status); Subject=$($signature.Subject)"
            if ($hashMatched) { $evidence = "Known Ohook hash matched. $evidence" }
            elseif (-not $signature.IsMicrosoft) { $evidence = "Non-Microsoft Office sppc hook DLL. $evidence" }

            New-CLAdvancedIndicator -Type 'OfficeCrackOhook' -Name 'Office Crack Ohook' -Location $candidate -Evidence $evidence -Severity $severity
        }
    }
}

function Get-CLHwidIndicators {
    param([string[]]$HwidArtifactPaths)

    foreach ($pathRule in @($HwidArtifactPaths)) {
        $path = Expand-CLAdvancedPath -Path $pathRule
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { continue }

        $type = if (Test-Path -LiteralPath $path -PathType Leaf) { 'WindowsCrackHWIDFile' } else { 'WindowsCrackHWIDFolder' }
        New-CLAdvancedIndicator -Type $type -Name 'Windows Crack HWID' -Location $path -Evidence 'HWID/MAS digital-license activation artifact exists on disk.' -Severity 'High'
    }
}

function Test-CLVolumeActivationProduct {
    param([object[]]$WindowsLicenses, [object[]]$OfficeLicenses)

    $windowsVolume = @($WindowsLicenses | Where-Object { $_.Description -match 'KMS|VOLUME|GVLK|MAK|Volume' }).Count -gt 0
    $officeVolume = @($OfficeLicenses | Where-Object { $_.RawSummary -match 'KMS|VOLUME|GVLK|MAK|Volume' -or $_.ProductName -match 'Volume|LTSC|2016|2019|2021|2024' }).Count -gt 0
    $windowsVolume -or $officeVolume
}

function Get-CLTsforgeIndicators {
    param(
        [string[]]$SppStorePaths,
        [object[]]$WindowsLicenses,
        [object[]]$OfficeLicenses,
        [object[]]$KmsInfo,
        [object[]]$ExistingIndicators
    )

    $hasActivationToolTrace = @($ExistingIndicators | Where-Object { $_.Name -match 'TSforge|MAS|Microsoft Activation Scripts|KMS38|HWID' -or $_.Evidence -match 'TSforge|MAS|Microsoft Activation Scripts|KMS38|HWID' }).Count -gt 0
    $hasSuspiciousKms = @($KmsInfo | Where-Object { $_.IsSuspicious }).Count -gt 0
    $hasVolumeProduct = Test-CLVolumeActivationProduct -WindowsLicenses $WindowsLicenses -OfficeLicenses $OfficeLicenses
    $recentThreshold = (Get-Date).AddDays(-14)

    foreach ($pathRule in @($SppStorePaths)) {
        $path = Expand-CLAdvancedPath -Path $pathRule
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }

        try { $item = Get-Item -LiteralPath $path -ErrorAction Stop }
        catch { continue }

        $isRecent = $item.LastWriteTime -gt $recentThreshold
        $isSuspicious = ($hasActivationToolTrace -or $hasSuspiciousKms) -and ($hasVolumeProduct -or $isRecent)
        if (-not $isSuspicious) { continue }

        $hash = Get-CLFileSha256 -Path $path
        $reasons = New-Object System.Collections.Generic.List[string]
        if ($hasActivationToolTrace) { $reasons.Add('activation-tool trace exists') }
        if ($hasSuspiciousKms) { $reasons.Add('suspicious KMS context exists') }
        if ($hasVolumeProduct) { $reasons.Add('volume/SPP-managed product is present') }
        if ($isRecent) { $reasons.Add("SPP store modified within 14 days ($($item.LastWriteTime.ToString('s')))") }

        New-CLAdvancedIndicator -Type 'SppStoreTsforge' -Name 'Windows/Office Crack TSforge' -Location $path -Evidence "SPP store anomaly consistent with TSforge: $($reasons -join '; '); Size=$($item.Length); SHA256=$hash" -Severity 'High'
    }
}

function Get-CLAdvancedActivationIndicators {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Rules,
        [object[]]$WindowsLicenses = @(),
        [object[]]$OfficeLicenses = @(),
        [object[]]$KmsInfo = @(),
        [object[]]$ExistingIndicators = @()
    )

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($indicator in @(Get-CLOfficeHookIndicators -OfficeSearchRoots @($Rules.officeSearchRoots) -OfficeHookFileNames @($Rules.officeHookFileNames) -KnownOhookSha256 @($Rules.knownOhookSha256))) { $results.Add($indicator) }
    foreach ($indicator in @(Get-CLHwidIndicators -HwidArtifactPaths @($Rules.hwidArtifactPaths))) { $results.Add($indicator) }
    foreach ($indicator in @(Get-CLTsforgeIndicators -SppStorePaths @($Rules.sppStorePaths) -WindowsLicenses $WindowsLicenses -OfficeLicenses $OfficeLicenses -KmsInfo $KmsInfo -ExistingIndicators $ExistingIndicators)) { $results.Add($indicator) }

    @($results.ToArray())
}

Export-ModuleMember -Function Get-CLAdvancedActivationIndicators
