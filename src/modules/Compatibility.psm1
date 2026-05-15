function Test-CLCompatibility {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $build = if ($os) { [int]$os.BuildNumber } else { 0 }
    $isWindows10Or11 = ($os.Caption -match 'Windows 10|Windows 11') -or ($build -ge 10240)

    [pscustomobject]@{
        ComputerName          = $env:COMPUTERNAME
        OSName                = $os.Caption
        Version               = $os.Version
        BuildNumber           = $build
        MinimumSupportedBuild = 10240
        RecommendedBuild      = 19044
        IsWindows10Or11       = [bool]$isWindows10Or11
        IsSupported           = [bool]($isWindows10Or11 -and $build -ge 10240)
        SupportNote           = if ($build -ge 19044) { 'Fully supported Windows 10/11 build.' } elseif ($build -ge 10240) { 'Supported, but Windows 10 21H2 build 19044 or newer is recommended.' } else { 'Unsupported Windows build.' }
        PowerShellVersion     = $PSVersionTable.PSVersion.ToString()
        IsAdmin               = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

Export-ModuleMember -Function Test-CLCompatibility