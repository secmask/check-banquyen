function Get-CLKmsInfo {
    [CmdletBinding()]
    param(
        [string[]]$SuspiciousKeywords = @('localhost', '127.0.0.1', 'vlmcsd', 'kms8', 'kms9', 'msguides', 'kmsauto')
    )

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\OfficeSoftwareProtectionPlatform'
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if (-not $item) { continue }

        $name = $item.KeyManagementServiceName
        $port = $item.KeyManagementServicePort
        $matched = @($SuspiciousKeywords | Where-Object { $name -and $name.ToString().ToLowerInvariant().Contains($_.ToLowerInvariant()) })

        [pscustomobject]@{
            RegistryPath = $path
            KeyManagementServiceName = $name
            KeyManagementServicePort = $port
            IsConfigured = -not [string]::IsNullOrWhiteSpace($name)
            IsSuspicious = $matched.Count -gt 0
            MatchedKeywords = $matched
        }
    }
}

Export-ModuleMember -Function Get-CLKmsInfo