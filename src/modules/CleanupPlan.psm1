function New-CLCleanupAction {
    param(
        [string]$Id,
        [string]$Category,
        [string]$Name,
        [string]$Action,
        [string]$Target,
        [string]$Reason,
        [string]$CommandPreview,
        [string]$Risk = 'Medium',
        [bool]$RestartRecommended = $false,
        [string]$RestartReason = 'No restart is usually required.'
    )

    [pscustomobject]@{
        Id                 = $Id
        Category           = $Category
        Name               = $Name
        Action             = $Action
        Target             = $Target
        Reason             = $Reason
        CommandPreview     = $CommandPreview
        Risk               = $Risk
        Mode               = 'DryRun'
        WillModifySystem   = $false
        RestartRecommended = $RestartRecommended
        RestartReason      = $RestartReason
    }
}

function New-CLCleanupPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object]$ScanResult)

    $actions = New-Object System.Collections.Generic.List[object]
    $index = 1

    foreach ($kms in @($ScanResult.KmsInfo | Where-Object { $_.IsConfigured })) {
        $actions.Add((New-CLCleanupAction -Id "CLN-$index" -Category 'KMS' -Name $kms.KeyManagementServiceName -Action 'Clear configured KMS host' -Target $kms.RegistryPath -Reason "Configured KMS host: $($kms.KeyManagementServiceName):$($kms.KeyManagementServicePort)" -CommandPreview 'slmgr.vbs /ckms or Office OSPP.VBS /remhst, depending on target' -Risk $(if ($kms.IsSuspicious) { 'High' } else { 'Medium' }) -RestartRecommended $true -RestartReason 'Restart may be needed for Windows/Office licensing services to reload cleared KMS settings.'))
        $index++
    }

    foreach ($indicator in @($ScanResult.Indicators)) {
        $command = switch ($indicator.Type) {
            'Service' { "sc.exe delete '$($indicator.Name)'" }
            'ServicePath' { "Review service '$($indicator.Name)' before deleting or disabling it" }
            'ScheduledTask' { "Unregister-ScheduledTask -TaskName '$($indicator.Name)' -Confirm" }
            'RunKey' { "Remove-ItemProperty -LiteralPath '$($indicator.Location)' -Name '$($indicator.Name)'" }
            'ImageFileExecutionOptions' { "Remove the Debugger value from '$($indicator.Location)'" }
            'OfficeProtectionRegistry' { "Review and remove suspicious Office protection registry value '$($indicator.Name)'" }
            'OfficeCrackOhook' { "Move-Item -LiteralPath '$($indicator.Location)' to quarantine" }
            'WindowsCrackHWIDFile' { "Move-Item -LiteralPath '$($indicator.Location)' to quarantine" }
            'WindowsCrackHWIDFolder' { "Move-Item -LiteralPath '$($indicator.Location)' to quarantine" }
            'SppStoreTsforge' { 'Manual review required; do not delete SPP store files automatically' }
            'File' { "Move-Item -LiteralPath '$($indicator.Location)' to quarantine" }
            'Folder' { "Move-Item -LiteralPath '$($indicator.Location)' to quarantine" }
            default { 'Manual review required' }
        }

        $needsRestart = $indicator.Type -in @('Service', 'ServicePath', 'ImageFileExecutionOptions', 'OfficeProtectionRegistry', 'OfficeCrackOhook', 'WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder', 'File', 'Folder')
        $restartReason = if ($indicator.Type -eq 'SppStoreTsforge') { 'Do not remove SPP store files automatically; review entitlement and consider official Microsoft repair/reactivation steps.' } elseif ($needsRestart) { 'Restart is recommended after removing service hooks, IFEO hooks, protection registry values, or loaded files.' } else { 'No restart is usually required after removing this persistence entry.' }
        $actions.Add((New-CLCleanupAction -Id "CLN-$index" -Category $indicator.Type -Name $indicator.Name -Action 'Review suspicious activation trace' -Target $indicator.Location -Reason $indicator.Evidence -CommandPreview $command -Risk $indicator.Severity -RestartRecommended $needsRestart -RestartReason $restartReason))
        $index++
    }

    foreach ($office in @($ScanResult.OfficeLicenses | Where-Object { $_.PartialProductKey -and $_.Source -eq 'ospp.vbs' })) {
        $actions.Add((New-CLCleanupAction -Id "CLN-$index" -Category 'Office' -Name $office.ProductName -Action 'Remove installed Office product key' -Target $office.ToolPath -Reason "Office partial product key detected: $($office.PartialProductKey)" -CommandPreview "cscript.exe '$($office.ToolPath)' /unpkey:$($office.PartialProductKey)" -Risk 'High' -RestartRecommended $true -RestartReason 'Restart Office apps, and reboot Windows if Office still reports the old licensing state.'))
        $index++
    }

    $hasOfficeCrack = @($ScanResult.Indicators | Where-Object { $_.Type -in @('OfficeCrackOhook', 'OfficeProtectionRegistry') }).Count -gt 0
    if ($hasOfficeCrack) {
        $actions.Add((New-CLCleanupAction -Id "CLN-$index" -Category 'OfficeActivationReset' -Name 'Office license cache' -Action 'Reset Office activation cache' -Target 'Current user Office licensing cache' -Reason 'Office crack was detected; reset local Office activation tokens and registry cache so Office returns to unlicensed/sign-in-required state.' -CommandPreview 'Remove Office LicensingNext, Identity, local license token folders, and Office credentials' -Risk 'High' -RestartRecommended $true -RestartReason 'Close Office apps before cleanup; restart Office or Windows to refresh activation state.'))
        $index++
    }

    $hasWindowsCrack = @($ScanResult.Indicators | Where-Object { $_.Type -in @('WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder', 'SppStoreTsforge', 'ImageFileExecutionOptions') -or ($_.Name -match 'HWID|KMS38|TSforge|MAS') }).Count -gt 0
    $hasWindowsKms = @($ScanResult.KmsInfo | Where-Object { $_.RegistryPath -match 'SoftwareProtectionPlatform' -and $_.IsConfigured }).Count -gt 0
    if ($hasWindowsCrack -or $hasWindowsKms) {
        $actions.Add((New-CLCleanupAction -Id "CLN-$index" -Category 'WindowsActivationReset' -Name 'Windows activation state' -Action 'Reset Windows activation state' -Target 'Windows Software Protection Platform' -Reason 'Windows crack or suspicious Windows activation configuration was detected; remove installed Windows product key and clear configured KMS host so Windows returns to unlicensed/not-activated state.' -CommandPreview 'slmgr.vbs /upk; slmgr.vbs /cpky; slmgr.vbs /ckms' -Risk 'High' -RestartRecommended $true -RestartReason 'Restart Windows after resetting activation state so Software Protection reloads cleanly.'))
        $index++
    }

    $summary = if ($actions.Count -gt 0) { "$($actions.Count) cleanup action(s) available for review. No changes were made." } else { 'No cleanup actions were suggested.' }
    $restartRecommended = @($actions.ToArray() | Where-Object { $_.RestartRecommended }).Count -gt 0

    [pscustomobject]@{
        GeneratedAt        = (Get-Date).ToString('o')
        Mode               = 'DryRun'
        Summary            = $summary
        RestartRecommended = $restartRecommended
        RestartNotice      = if ($restartRecommended) { 'Restart may be required after applying selected cleanup actions.' } else { 'Restart is not expected for the suggested actions.' }
        Actions            = @($actions.ToArray())
    }
}

Export-ModuleMember -Function New-CLCleanupPlan