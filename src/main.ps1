[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$NoReport,
    [switch]$VerboseLog,
    [switch]$Menu,
    [switch]$Gui,
    [switch]$ApplyCleanup,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$moduleRoot = Join-Path $PSScriptRoot 'modules'
$rulesPath = Join-Path $PSScriptRoot 'config\rules.json'
$reportRoot = Join-Path $env:ProgramData 'CheckLicense\reports'

if ($VerboseLog) { $VerbosePreference = 'Continue' }

function Import-CLModules {
    foreach ($module in @('Compatibility', 'WindowsLicense', 'VNextLicense', 'OfficeLicense', 'KmsScanner', 'CrackIndicatorScanner', 'RiskScore', 'Report', 'CleanupPlan', 'CleanupApply')) {
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
    $indicators = @(Get-CLCrackIndicators -IndicatorNames @($Rules.indicatorNames) -IndicatorPaths @($Rules.indicatorPaths))

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

function Write-CLHeader {
    Clear-Host
    $isAdmin = Test-CLAdmin
    Write-Host ''
    Write-Host '  Check License' -ForegroundColor Cyan
    Write-Host '  Windows & Office compliance scanner' -ForegroundColor DarkCyan
    Write-Host "  Administrator: $isAdmin | No activation | No internet upload" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Yellow' })
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkGray
}

function Write-CLMenu {
    Write-Host ''
    Write-Host '  Chon tac vu' -ForegroundColor White
    Write-Host '  [1] Scan nhanh va xem tom tat' -ForegroundColor Green
    Write-Host '  [2] Scan day du va luu JSON/CSV report' -ForegroundColor Green
    Write-Host '  [3] Xuat ket qua JSON ra man hinh' -ForegroundColor Yellow
    Write-Host '  [4] Xem report gan nhat' -ForegroundColor Cyan
    Write-Host '  [5] Mo thu muc report' -ForegroundColor Cyan
    Write-Host '  [0] Thoat' -ForegroundColor DarkGray
    Write-Host ''
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
        Write-Host "  CSV : $($Result.Report.CsvPath)" -ForegroundColor DarkCyan
    }
}

function Show-CLLatestReport {
    if (-not (Test-Path -LiteralPath $reportRoot)) {
        Write-Host '  Chua co thu muc report.' -ForegroundColor Yellow
        return
    }

    $latest = Get-ChildItem -LiteralPath $reportRoot -Filter 'check-license-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

    if (-not $latest) {
        Write-Host '  Chua co file JSON report.' -ForegroundColor Yellow
        return
    }

    Write-Host "  Report gan nhat: $($latest.FullName)" -ForegroundColor Cyan
    Get-Content -LiteralPath $latest.FullName -Raw
}

function Open-CLReportFolder {
    New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
    Invoke-Item -LiteralPath $reportRoot
}

function Start-CLMenu {
    param([Parameter(Mandatory)] [object]$Rules)

    do {
        Write-CLHeader
        Write-CLMenu
        $choice = Read-Host '  Nhap lua chon'

        switch ($choice) {
            '1' {
                Write-Host '  Dang scan nhanh...' -ForegroundColor DarkCyan
                $result = Invoke-CLScan -Rules $Rules -NoReport
                Write-CLSummary -Result $result
                Read-Host '  Nhan Enter de quay lai menu' | Out-Null
            }
            '2' {
                Write-Host '  Dang scan day du va tao report...' -ForegroundColor DarkCyan
                $result = Invoke-CLScan -Rules $Rules
                Write-CLSummary -Result $result
                Read-Host '  Nhan Enter de quay lai menu' | Out-Null
            }
            '3' {
                $result = Invoke-CLScan -Rules $Rules -NoReport
                $result | ConvertTo-Json -Depth 8
                Read-Host '  Nhan Enter de quay lai menu' | Out-Null
            }
            '4' {
                Show-CLLatestReport
                Read-Host '  Nhan Enter de quay lai menu' | Out-Null
            }
            '5' { Open-CLReportFolder }
            '0' { return }
            default {
                Write-Host '  Lua chon khong hop le.' -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

try {
    if ($Gui) {
        & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'gui.ps1')
        exit $LASTEXITCODE
    }

    Import-CLModules
    $rules = Get-Content -LiteralPath $rulesPath -Raw -ErrorAction Stop | ConvertFrom-Json

    if ($Menu -or (-not $Json -and -not $NoReport -and $Host.Name -match 'ConsoleHost')) {
        Start-CLMenu -Rules $rules
        return
    }

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
