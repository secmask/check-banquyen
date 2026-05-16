function Get-CLRiskScore {
    [CmdletBinding()]
    param(
        [object[]]$WindowsLicenses,
        [object[]]$OfficeLicenses,
        [object[]]$KmsInfo,
        [object[]]$Indicators
    )

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    $ohookIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Type -eq 'OfficeCrackOhook' })
    $hwidIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Type -in @('WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder') })
    $tsforgeIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Type -eq 'SppStoreTsforge' })

    if ($ohookIndicators.Count -gt 0) { $score += 60; $reasons.Add('Office Crack Ohook detected') }
    if ($hwidIndicators.Count -gt 0) { $score += 55; $reasons.Add('Windows Crack HWID detected') }
    if ($tsforgeIndicators.Count -gt 0) { $score += 60; $reasons.Add('Windows/Office Crack TSforge detected') }

    if ($WindowsLicenses -and @($WindowsLicenses | Where-Object { -not $_.IsLicensed }).Count -gt 0) { $score += 30; $reasons.Add('Windows activation issue detected') }
    if ($OfficeLicenses -and @($OfficeLicenses | Where-Object { $_.LicenseStatusText -notin @('Licensed', 'Not Detected') }).Count -gt 0) { $score += 25; $reasons.Add('Office activation issue detected') }
    if (@($KmsInfo | Where-Object { $_.IsSuspicious }).Count -gt 0) { $score += 30; $reasons.Add('Suspicious KMS configuration keyword detected') }

    $advancedTypes = @('OfficeCrackOhook', 'WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder', 'SppStoreTsforge')
    $highIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Severity -eq 'High' -and $_.Type -notin $advancedTypes })
    $mediumIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Severity -ne 'High' -and $_.Type -notin $advancedTypes })
    if ($highIndicators.Count -gt 0) { $score += 45; $reasons.Add("High-confidence activation-tool indicator detected ($($highIndicators.Count))") }
    elseif ($mediumIndicators.Count -gt 0) { $score += 25; $reasons.Add("Activation-tool persistence indicator detected ($($mediumIndicators.Count))") }

    $level = if ($score -ge 60) { 'High' } elseif ($score -ge 30) { 'Medium' } elseif ($score -gt 0) { 'Low' } else { 'Low' }
    $category = if ($ohookIndicators.Count -gt 0 -or $hwidIndicators.Count -gt 0 -or $tsforgeIndicators.Count -gt 0) { 'Crack Detected' } elseif ($reasons -match 'KMS|indicator') { 'Suspicious Activation' } elseif ($reasons -match 'activation issue') { 'Activation Issue' } else { 'Low' }

    [pscustomobject]@{
        Score = [Math]::Min($score, 100)
        Level = $level
        Category = $category
        Reasons = @($reasons)
    }
}

Export-ModuleMember -Function Get-CLRiskScore
