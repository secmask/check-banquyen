[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$NoReport,
    [switch]$VerboseLog,
    [switch]$Gui,
    [switch]$ApplyCleanup,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$moduleRoot = Join-Path $PSScriptRoot 'modules'
$rulesPath = Join-Path $PSScriptRoot 'config\rules.json'

if ($VerboseLog) { $VerbosePreference = 'Continue' }

function Import-CLModules {
    foreach ($module in @('Compatibility', 'WindowsLicense', 'VNextLicense', 'OfficeLicense', 'KmsScanner', 'CrackIndicatorScanner', 'AdvancedActivationScanner', 'RiskScore', 'Report', 'CleanupPlan', 'CleanupApply')) {
        Import-Module (Join-Path $moduleRoot "$module.psm1") -Force -ErrorAction Stop
    }
}

function Invoke-CLScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Rules,
        [switch]$NoReport
    )

    Write-Verbose 'Scanning OS compatibility and activation state.'
    $compatibility = Test-CLCompatibility
    $windowsLicenses = @(Get-CLWindowsLicense)

    Write-Verbose 'Scanning Office activation state.'
    $officeLicenses = @(Get-CLOfficeLicense)

    Write-Verbose 'Scanning KMS configuration and common activation indicators.'
    $kmsInfo = @(Get-CLKmsInfo -SuspiciousKeywords @($Rules.suspiciousKmsKeywords))
    $baseIndicators = @(Get-CLCrackIndicators -IndicatorNames @($Rules.indicatorNames) -IndicatorPaths @($Rules.indicatorPaths))
    $advancedIndicators = @(Get-CLAdvancedActivationIndicators -Rules $Rules -WindowsLicenses $windowsLicenses -OfficeLicenses $officeLicenses -KmsInfo $kmsInfo -ExistingIndicators $baseIndicators)
    $indicators = @($baseIndicators + $advancedIndicators)

    $risk = Get-CLRiskScore -WindowsLicenses $windowsLicenses -OfficeLicenses $officeLicenses -KmsInfo $kmsInfo -Indicators $indicators

    $result = [pscustomobject]@{
        Tool            = 'check-license'
        GeneratedAt     = (Get-Date).ToString('o')
        Compatibility   = $compatibility
        WindowsLicenses = $windowsLicenses
        OfficeLicenses  = $officeLicenses
        KmsInfo         = $kmsInfo
        Indicators      = $indicators
        Risk            = $risk
        Report          = $null
    }

    $result.Report = New-CLReport -Data $result -NoReport:$NoReport
    $result
}

function Write-CLSummary {
    param([Parameter(Mandatory)] [object]$Result)

    $riskColor = switch ($Result.Risk.Level) {
        'High' { 'Red' }
        'Medium' { 'Yellow' }
        default { 'Green' }
    }

    Write-Host ''
    Write-Host '  Ket qua tom tat' -ForegroundColor White
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host "  May tinh    : $($Result.Compatibility.ComputerName)"
    Write-Host "  He dieu hanh: $($Result.Compatibility.OSName) build $($Result.Compatibility.BuildNumber)"
    Write-Host "  Ho tro      : $($Result.Compatibility.IsSupported)"
    Write-Host "  Rui ro      : $($Result.Risk.Level) / $($Result.Risk.Category) / score $($Result.Risk.Score)" -ForegroundColor $riskColor

    foreach ($item in @($Result.WindowsLicenses)) {
        Write-Host "  Windows     : $($item.LicenseStatusText) - $($item.ProductName)"
    }

    foreach ($item in @($Result.OfficeLicenses)) {
        Write-Host "  Office      : $($item.LicenseStatusText) - $($item.ProductName)"
    }

    $kmsSuspicious = @($Result.KmsInfo | Where-Object { $_.IsSuspicious }).Count
    $indicatorCount = @($Result.Indicators | Where-Object { $_.IsSuspicious }).Count
    Write-Host "  KMS dang ngo: $kmsSuspicious"
    Write-Host "  Dau hieu tool: $indicatorCount"

    if ($Result.Risk.Reasons.Count -gt 0) {
        Write-Host ''
        Write-Host '  Ly do danh gia:' -ForegroundColor White
        foreach ($reason in $Result.Risk.Reasons) { Write-Host "  - $reason" }
    }

    if ($Result.Report) {
        Write-Host ''
        Write-Host "  JSON: $($Result.Report.JsonPath)" -ForegroundColor DarkCyan
    }
}

try {
    if ($Gui -or (-not $Json -and -not $ApplyCleanup)) {
        & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'gui.ps1')
        exit $LASTEXITCODE
    }

    Import-CLModules
    $rules = Get-Content -LiteralPath $rulesPath -Raw -ErrorAction Stop | ConvertFrom-Json

    $result = Invoke-CLScan -Rules $rules -NoReport:$NoReport

    if ($ApplyCleanup) {
        $plan = New-CLCleanupPlan -ScanResult $result
        if (@($plan.Actions).Count -eq 0) {
            Write-Host 'No cleanup actions are available.' -ForegroundColor Green
        }
        elseif (-not $Force) {
            Write-Host 'Cleanup actions are available, but no changes were made.' -ForegroundColor Yellow
            Write-Host 'Re-run with -ApplyCleanup -Force from an elevated PowerShell session to apply cleanup.' -ForegroundColor Yellow
            $plan | ConvertTo-Json -Depth 8
            return
        }
        else {
            $cleanup = Invoke-CLCleanupPlan -Plan $plan -Force
            $cleanup | ConvertTo-Json -Depth 8
            return
        }
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        Write-Host 'check-license completed' -ForegroundColor Green
        Write-CLSummary -Result $result
        $result
    }
}
catch {
    Write-Error "check-license failed: $($_.Exception.Message)"
    exit 1
}
