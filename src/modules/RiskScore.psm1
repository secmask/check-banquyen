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

    if ($WindowsLicenses -and @($WindowsLicenses | Where-Object { -not $_.IsLicensed }).Count -gt 0) { $score += 30; $reasons.Add('Windows activation issue detected') }
    if ($OfficeLicenses -and @($OfficeLicenses | Where-Object { $_.LicenseStatusText -notin @('Licensed', 'Not Detected') }).Count -gt 0) { $score += 25; $reasons.Add('Office activation issue detected') }
    if (@($KmsInfo | Where-Object { $_.IsSuspicious }).Count -gt 0) { $score += 30; $reasons.Add('Suspicious KMS configuration keyword detected') }
    $highIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Severity -eq 'High' })
    $mediumIndicators = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Severity -ne 'High' })
    if ($highIndicators.Count -gt 0) { $score += 45; $reasons.Add("High-confidence activation-tool indicator detected ($($highIndicators.Count))") }
    elseif ($mediumIndicators.Count -gt 0) { $score += 25; $reasons.Add("Activation-tool persistence indicator detected ($($mediumIndicators.Count))") }

    $level = if ($score -ge 60) { 'High' } elseif ($score -ge 30) { 'Medium' } elseif ($score -gt 0) { 'Low' } else { 'Low' }
    $category = if ($reasons -match 'KMS|indicator') { 'Suspicious Activation' } elseif ($reasons -match 'activation issue') { 'Activation Issue' } else { 'Low' }

    [pscustomobject]@{
        Score = [Math]::Min($score, 100)
        Level = $level
        Category = $category
        Reasons = @($reasons)
    }
}

Export-ModuleMember -Function Get-CLRiskScore