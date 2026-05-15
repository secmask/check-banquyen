function Test-CLAdmin {
    [CmdletBinding()]
    param()

    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-CLApplyResult {
    param(
        [object]$Action,
        [string]$Status,
        [string]$Message,
        [string]$BackupPath = $null,
        [string]$QuarantinePath = $null
    )

    [pscustomobject]@{
        Id                 = $Action.Id
        Category           = $Action.Category
        Name               = $Action.Name
        Action             = $Action.Action
        Target             = $Action.Target
        Status             = $Status
        Message            = $Message
        BackupPath         = $BackupPath
        QuarantinePath     = $QuarantinePath
        RestartRecommended = [bool]$Action.RestartRecommended
        RestartReason      = $Action.RestartReason
    }
}

function New-CLSafeName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'item' }
    ($Name -replace '[\\/:*?"<>|]', '_').Trim()
}

function Backup-CLRegistryKey {
    param(
        [string]$RegistryPath,
        [string]$BackupRoot
    )

    if ($RegistryPath -notmatch '^HKLM:\\|^HKCU:\\') { return $null }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

    $nativePath = $RegistryPath -replace '^HKLM:', 'HKLM' -replace '^HKCU:', 'HKCU'
    $fileName = (New-CLSafeName -Name $nativePath) + '.reg'
    $backupPath = Join-Path $BackupRoot $fileName
    & reg.exe export $nativePath $backupPath /y | Out-Null
    if (Test-Path -LiteralPath $backupPath) { return $backupPath }
    return $null
}

function Move-CLToQuarantine {
    param(
        [string]$Path,
        [string]$QuarantineRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
    New-Item -ItemType Directory -Force -Path $QuarantineRoot | Out-Null

    $leaf = Split-Path -Path $Path -Leaf
    $target = Join-Path $QuarantineRoot ("{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), (New-CLSafeName -Name $leaf))
    Move-Item -LiteralPath $Path -Destination $target -Force -ErrorAction Stop
    return $target
}

function Invoke-CLCleanupAction {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [string]$BackupRoot,
        [Parameter(Mandatory)] [string]$QuarantineRoot
    )

    try {
        switch ($Action.Category) {
            'KMS' {
                $backup = Backup-CLRegistryKey -RegistryPath $Action.Target -BackupRoot $BackupRoot
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Clear configured KMS host')) {
                    if ($Action.Target -match 'OfficeSoftwareProtectionPlatform') {
                        $ospp = Get-ChildItem -LiteralPath "$env:ProgramFiles\Microsoft Office", "${env:ProgramFiles(x86)}\Microsoft Office" -Recurse -Filter 'OSPP.VBS' -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($ospp) { & cscript.exe //nologo $ospp.FullName /remhst | Out-Null }
                    }
                    else {
                        & cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ckms | Out-Null
                    }
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Configured KMS host cleared.' -BackupPath $backup
            }
            'Service' {
                if ($PSCmdlet.ShouldProcess($Action.Name, 'Stop and delete suspicious service')) {
                    Stop-Service -Name $Action.Name -Force -ErrorAction SilentlyContinue
                    & sc.exe delete $Action.Name | Out-Null
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious service removal requested.'
            }
            'ScheduledTask' {
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Unregister suspicious scheduled task')) {
                    Unregister-ScheduledTask -TaskName $Action.Name -TaskPath $Action.Target -Confirm:$false -ErrorAction Stop
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious scheduled task removed.'
            }
            'RunKey' {
                $backup = Backup-CLRegistryKey -RegistryPath $Action.Target -BackupRoot $BackupRoot
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Remove suspicious Run key value')) {
                    Remove-ItemProperty -LiteralPath $Action.Target -Name $Action.Name -ErrorAction Stop
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious startup value removed.' -BackupPath $backup
            }
            'ImageFileExecutionOptions' {
                $backup = Backup-CLRegistryKey -RegistryPath $Action.Target -BackupRoot $BackupRoot
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Remove IFEO Debugger hook')) {
                    Remove-ItemProperty -LiteralPath $Action.Target -Name 'Debugger' -ErrorAction Stop
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'IFEO Debugger hook removed.' -BackupPath $backup
            }
            'OfficeProtectionRegistry' {
                $backup = Backup-CLRegistryKey -RegistryPath $Action.Target -BackupRoot $BackupRoot
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Remove suspicious Office protection registry value')) {
                    Remove-ItemProperty -LiteralPath $Action.Target -Name $Action.Name -ErrorAction Stop
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious Office protection registry value removed.' -BackupPath $backup
            }
            'File' {
                $quarantine = $null
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Move suspicious file to quarantine')) {
                    $quarantine = Move-CLToQuarantine -Path $Action.Target -QuarantineRoot $QuarantineRoot
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious file moved to quarantine.' -QuarantinePath $quarantine
            }
            'Folder' {
                $quarantine = $null
                if ($PSCmdlet.ShouldProcess($Action.Target, 'Move suspicious folder to quarantine')) {
                    $quarantine = Move-CLToQuarantine -Path $Action.Target -QuarantineRoot $QuarantineRoot
                }
                return New-CLApplyResult -Action $Action -Status 'Applied' -Message 'Suspicious folder moved to quarantine.' -QuarantinePath $quarantine
            }
            'Office' {
                if ($Action.CommandPreview -match '/unpkey:([A-Z0-9]{5})') {
                    $partialKey = $matches[1]
                    if ($PSCmdlet.ShouldProcess($Action.Target, 'Remove installed Office product key')) {
                        & cscript.exe //nologo $Action.Target /unpkey:$partialKey | Out-Null
                    }
                    return New-CLApplyResult -Action $Action -Status 'Applied' -Message "Office product key ending $partialKey removed."
                }
                return New-CLApplyResult -Action $Action -Status 'Skipped' -Message 'Office partial key was not available.'
            }
            default {
                return New-CLApplyResult -Action $Action -Status 'Skipped' -Message 'Manual review required for this action type.'
            }
        }
    }
    catch {
        return New-CLApplyResult -Action $Action -Status 'Failed' -Message $_.Exception.Message
    }
}

function Invoke-CLCleanupPlan {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [object]$Plan,
        [string]$OutputRoot = (Join-Path $env:ProgramData 'CheckLicense\cleanup'),
        [switch]$Force
    )

    if (-not (Test-CLAdmin)) { throw 'Administrator privileges are required to apply cleanup actions.' }
    if (-not $Force) { throw 'Use -Force after user confirmation to apply cleanup actions.' }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $sessionRoot = Join-Path $OutputRoot $stamp
    $backupRoot = Join-Path $sessionRoot 'registry-backup'
    $quarantineRoot = Join-Path $sessionRoot 'quarantine'
    New-Item -ItemType Directory -Force -Path $sessionRoot | Out-Null

    $results = foreach ($action in @($Plan.Actions)) {
        Invoke-CLCleanupAction -Action $action -BackupRoot $backupRoot -QuarantineRoot $quarantineRoot
    }

    $restartRecommended = @($results | Where-Object { $_.RestartRecommended -and $_.Status -eq 'Applied' }).Count -gt 0
    $summary = [pscustomobject]@{
        GeneratedAt        = (Get-Date).ToString('o')
        SessionRoot        = $sessionRoot
        BackupRoot         = $backupRoot
        QuarantineRoot     = $quarantineRoot
        AppliedCount       = @($results | Where-Object { $_.Status -eq 'Applied' }).Count
        FailedCount        = @($results | Where-Object { $_.Status -eq 'Failed' }).Count
        SkippedCount       = @($results | Where-Object { $_.Status -eq 'Skipped' }).Count
        RestartRecommended = $restartRecommended
        RestartNotice      = if ($restartRecommended) { 'Restart Windows after cleanup to unload activation hooks and refresh licensing services.' } else { 'Restart is not expected based on applied actions.' }
        Results            = @($results)
    }

    $logPath = Join-Path $sessionRoot 'cleanup-result.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logPath -Encoding UTF8
    $summary | Add-Member -NotePropertyName LogPath -NotePropertyValue $logPath -Force
    $summary
}

Export-ModuleMember -Function Invoke-CLCleanupPlan, Test-CLAdmin