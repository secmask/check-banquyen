function Expand-CLPath {
    param([string]$Path)
    [Environment]::ExpandEnvironmentVariables($Path)
}

function New-CLIndicator {
    param(
        [string]$Type,
        [string]$Name,
        [string]$Location,
        [string]$Evidence,
        [string]$Severity = 'Medium'
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

function Test-CLNameMatch {
    param(
        [string]$Text,
        [string[]]$Names
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    @($Names | Where-Object { $Text -like "*$_*" } | Select-Object -First 1)
}

function Get-CLCrackIndicators {
    [CmdletBinding()]
    param(
        [string[]]$IndicatorNames = @('AutoKMS', 'KMSpico', 'KMSAuto', 'AAct', 'vlmcsd'),
        [string[]]$IndicatorPaths = @()
    )

    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    Get-Service -ErrorAction SilentlyContinue | ForEach-Object {
        $matched = @(Test-CLNameMatch -Text "$($_.Name) $($_.DisplayName)" -Names $IndicatorNames)
        if ($matched.Count -gt 0) {
            $key = "Service|$($_.Name)"
            if ($seen.Add($key)) { New-CLIndicator -Type 'Service' -Name $_.Name -Location $_.DisplayName -Evidence "Matched keyword: $($matched[0])" -Severity 'High' }
        }
    }

    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
        $text = "$($_.Name) $($_.DisplayName) $($_.PathName)"
        $matched = @(Test-CLNameMatch -Text $text -Names $IndicatorNames)
        if ($matched.Count -gt 0) {
            $key = "ServicePath|$($_.Name)"
            if ($seen.Add($key)) { New-CLIndicator -Type 'ServicePath' -Name $_.Name -Location $_.PathName -Evidence "Matched keyword: $($matched[0])" -Severity 'High' }
        }
    }

    Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
        $actions = @($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
        $text = "$($_.TaskName) $($_.TaskPath) $actions"
        $matched = @(Test-CLNameMatch -Text $text -Names $IndicatorNames)
        if ($matched.Count -gt 0) {
            $key = "ScheduledTask|$($_.TaskPath)$($_.TaskName)"
            if ($seen.Add($key)) { New-CLIndicator -Type 'ScheduledTask' -Name $_.TaskName -Location $_.TaskPath -Evidence "Matched keyword: $($matched[0])" -Severity 'High' }
        }
    }

    $runKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($runKey in $runKeys) {
        $item = Get-ItemProperty -LiteralPath $runKey -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($prop in @($item.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
            $text = "$($prop.Name) $($prop.Value)"
            $matched = @(Test-CLNameMatch -Text $text -Names $IndicatorNames)
            if ($matched.Count -gt 0) {
                $key = "RunKey|$runKey|$($prop.Name)"
                if ($seen.Add($key)) { New-CLIndicator -Type 'RunKey' -Name $prop.Name -Location $runKey -Evidence "Matched keyword: $($matched[0]); Value=$($prop.Value)" -Severity 'High' }
            }
        }
    }

    $osppPaths = @(
        'HKLM:\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\OfficeSoftwareProtectionPlatform'
    )
    foreach ($osppPath in $osppPaths) {
        $item = Get-ItemProperty -LiteralPath $osppPath -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($propertyName in @('Path', 'ServiceDll', 'PluginDll', 'KeyManagementServiceName')) {
            $value = $item.PSObject.Properties[$propertyName].Value
            $matched = @(Test-CLNameMatch -Text $value -Names $IndicatorNames)
            if ($matched.Count -gt 0) {
                $key = "OfficeProtection|$osppPath|$propertyName"
                if ($seen.Add($key)) { New-CLIndicator -Type 'OfficeProtectionRegistry' -Name $propertyName -Location $osppPath -Evidence "Matched keyword: $($matched[0]); Value=$value" -Severity 'High' }
            }
        }
    }

    $imageOptionsRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    foreach ($imageName in @('sppsvc.exe', 'osppsvc.exe', 'OfficeClickToRun.exe')) {
        $imagePath = Join-Path $imageOptionsRoot $imageName
        $item = Get-ItemProperty -LiteralPath $imagePath -ErrorAction SilentlyContinue
        if ($item -and $item.Debugger) {
            $matched = @(Test-CLNameMatch -Text $item.Debugger -Names $IndicatorNames)
            $severity = if ($matched.Count -gt 0) { 'High' } else { 'Medium' }
            $key = "IFEO|$imageName"
            if ($seen.Add($key)) { New-CLIndicator -Type 'ImageFileExecutionOptions' -Name $imageName -Location $imagePath -Evidence "Debugger=$($item.Debugger)" -Severity $severity }
        }
    }

    foreach ($path in $IndicatorPaths) {
        $expanded = Expand-CLPath -Path $path
        if ($expanded -and (Test-Path -LiteralPath $expanded)) {
            $type = if (Test-Path -LiteralPath $expanded -PathType Leaf) { 'File' } else { 'Folder' }
            $key = "$type|$expanded"
            if ($seen.Add($key)) { New-CLIndicator -Type $type -Name (Split-Path -Leaf $expanded) -Location $expanded -Evidence 'Known activation-tool path exists' -Severity 'High' }
        }
    }
}

Export-ModuleMember -Function Get-CLCrackIndicators