function Invoke-CLVNextDiagnostic {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "vnextdiag.ps1 not found: $Path"
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path -action list 2>&1 | Out-String
}

Export-ModuleMember -Function Invoke-CLVNextDiagnostic