[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$moduleRoot = Join-Path $PSScriptRoot 'modules'
$rulesPath = Join-Path $PSScriptRoot 'config\rules.json'
$reportRoot = Join-Path $env:ProgramData 'CheckLicense\reports'

foreach ($module in @('Compatibility', 'WindowsLicense', 'VNextLicense', 'OfficeLicense', 'KmsScanner', 'CrackIndicatorScanner', 'AdvancedActivationScanner', 'RiskScore', 'Report', 'CleanupPlan', 'CleanupApply')) {
    Import-Module (Join-Path $moduleRoot "$module.psm1") -Force -ErrorAction Stop
}

$rules = Get-Content -LiteralPath $rulesPath -Raw -ErrorAction Stop | ConvertFrom-Json
$lastResult = $null
$scanJob = $null
$progressTimer = $null
$language = 'en'

$text = @{
    en = @{
        AppTitle              = 'Check License'
        AppSubtitle           = 'Windows and Office license compliance scanner'
        ReadyTitle            = 'Ready to scan'
        ReadyStatus           = 'Click CHECK to scan Windows, Office, KMS settings, and common activation indicators.'
        Check                 = 'CHECK'
        Checking              = 'CHECKING...'
        Overview              = 'Overview'
        ModeAdmin             = "Scans Windows and Office license status.`nChecks KMS, services, tasks, registry, and files.`nCreates reports and safe cleanup plans."
        ModeStandard          = "Scans Windows and Office license status.`nChecks KMS, services, tasks, registry, and files.`nCreates reports and safe cleanup plans."
        Status                = 'Status'
        NotScanned            = 'Not scanned'
        WaitingForCheck       = 'Waiting for CHECK'
        ReviewCleanupPlan     = 'Details'
        ApplyCleanup          = 'Remove Crack'
        Windows               = 'Windows'
        Office                = 'Office'
        Kms                   = 'KMS'
        Indicators            = 'Indicators'
        Waiting               = 'Waiting'
        AuditDetails          = 'Audit details'
        StandardUser          = 'STANDARD USER'
        Administrator         = 'ADMINISTRATOR'
        PreparingScan         = 'Preparing scan...'
        StartingScan          = 'Starting read-only license check...'
        CheckingCompatibility = 'Checking compatibility...'
        CheckingWindows       = 'Checking Windows license...'
        CheckingOffice        = 'Checking Office license...'
        CheckingKms           = 'Checking KMS configuration...'
        CheckingIndicators    = 'Checking activation indicators...'
        CalculatingRisk       = 'Calculating risk score...'
        SavingReport          = 'Saving report...'
        ScanCompleted         = 'Scan completed.'
        ScanFailed            = 'Scan failed.'
        Passed                = 'PASSED'
        UninstallSafe         = 'CLEANUP READY'
        NoCrackDetected       = 'No crack found'
        CleanupAvailable      = 'Cleanup ready'
        Licensed              = 'LICENSED'
        DetectCracked         = 'SUSPECT'
        NoSuspiciousKms       = 'No KMS'
        Suspicious            = 'suspicious'
        Found                 = 'found'
        NoIndicator           = 'None'
        RunCheckFirstPlan     = 'Run CHECK first to create a cleanup plan.'
        RunCheckFirstApply    = 'Run CHECK first before applying cleanup.'
        CleanupAssistant      = 'Details'
        CleanupDryRun         = 'Crack detection details'
        DryRunNoChange        = 'Reasons for the conclusion and cleanup actions are listed below.'
        DryRunGenerated       = 'Detection details displayed.'
        NoActions             = 'No cleanup actions are available.'
        AdminRequiredTitle    = 'Administrator required'
        AdminRequired         = 'Uninstall Crack requires Administrator privileges. Click OK to restart Check License as Administrator.'
        ConfirmApplyTitle     = 'Remove Crack'
        ConfirmApply          = 'Ready to remove detected activation cracks.`r`n`r`nActions: {0}`r`nSafety: registry backup, quarantine, cleanup log`r`nRestart: {1}`r`n`r`nContinue cleanup?'
        ApplyingCleanup       = 'Applying cleanup actions...'
        ApplyingCleanupLog    = 'Applying cleanup actions with backup/quarantine...'
        CleanupCompleted      = 'Cleanup completed.'
        CleanupCompletedMsg   = 'Cleanup completed.`r`nApplied: {0}, Failed: {1}, Skipped: {2}`r`n{3}'
        CleanupFailed         = 'Cleanup failed.'
        ApplyCleanupError     = 'Apply Cleanup error'
        ReadyLog              = 'Ready. Click CHECK to scan and save report.'
    }
    vi = @{
        AppTitle              = 'Kiểm tra bản quyền'
        AppSubtitle           = 'Công cụ kiểm tra bản quyền Windows và Office'
        ReadyTitle            = 'Sẵn sàng quét'
        ReadyStatus           = 'Bấm CHECK để quét Windows, Office, KMS và các dấu hiệu kích hoạt bất thường.'
        Check                 = 'CHECK'
        Checking              = 'ĐANG CHECK...'
        Overview              = 'Tổng quan'
        ModeAdmin             = "Quét bản quyền Windows và Office.`nKiểm tra KMS, service, task, registry và file.`nTạo report và kế hoạch gỡ an toàn."
        ModeStandard          = "Quét bản quyền Windows và Office.`nKiểm tra KMS, service, task, registry và file.`nTạo report và kế hoạch gỡ an toàn."
        Status                = 'Trạng thái'
        NotScanned            = 'Chưa quét'
        WaitingForCheck       = 'Đang chờ bấm CHECK'
        ReviewCleanupPlan     = 'Chi tiết'
        ApplyCleanup          = 'Gỡ crack'
        Windows               = 'Windows'
        Office                = 'Office'
        Kms                   = 'KMS'
        Indicators            = 'Dấu hiệu'
        Waiting               = 'Đang chờ'
        AuditDetails          = 'Chi tiết kiểm tra'
        StandardUser          = 'USER THƯỜNG'
        Administrator         = 'ADMINISTRATOR'
        PreparingScan         = 'Đang chuẩn bị quét...'
        StartingScan          = 'Bắt đầu kiểm tra bản quyền chỉ-đọc...'
        CheckingCompatibility = 'Đang kiểm tra tương thích...'
        CheckingWindows       = 'Đang kiểm tra bản quyền Windows...'
        CheckingOffice        = 'Đang kiểm tra bản quyền Office...'
        CheckingKms           = 'Đang kiểm tra cấu hình KMS...'
        CheckingIndicators    = 'Đang kiểm tra dấu hiệu kích hoạt bất thường...'
        CalculatingRisk       = 'Đang tính điểm rủi ro...'
        SavingReport          = 'Đang lưu report...'
        ScanCompleted         = 'Quét hoàn tất.'
        ScanFailed            = 'Quét thất bại.'
        Passed                = 'HỢP LỆ'
        UninstallSafe         = 'CÓ THỂ GỠ'
        NoCrackDetected       = 'Không có crack'
        CleanupAvailable      = 'Có thể gỡ'
        Licensed              = 'CÓ BẢN QUYỀN'
        DetectCracked         = 'NGHI NGỜ'
        NoSuspiciousKms       = 'KHÔNG CÓ KMS'
        Suspicious            = 'ĐÁNG NGỜ'
        Found                 = 'TÌM THẤY'
        NoIndicator           = 'KHÔNG PHÁT HIỆN'
        RunCheckFirstPlan     = 'Hãy bấm CHECK trước để tạo kế hoạch gỡ.'
        RunCheckFirstApply    = 'Hãy bấm CHECK trước khi gỡ crack.'
        CleanupAssistant      = 'Chi tiết'
        CleanupDryRun         = 'Chi tiết kết luận crack'
        DryRunNoChange        = 'Nguyên nhân kết luận và hành động gỡ được liệt kê bên dưới.'
        DryRunGenerated       = 'Đã hiển thị chi tiết kết luận.'
        NoActions             = 'Không có hành động gỡ nào.'
        AdminRequiredTitle    = 'Cần quyền Administrator'
        AdminRequired         = 'Gỡ crack cần quyền Administrator. Bấm OK để khởi động lại Check License bằng quyền Administrator.'
        ConfirmApplyTitle     = 'Gỡ crack'
        ConfirmApply          = 'Sẵn sàng gỡ các dấu hiệu kích hoạt crack đã phát hiện.`r`n`r`nHành động: {0}`r`nAn toàn: backup registry, quarantine file, lưu log`r`nKhởi động lại: {1}`r`n`r`nTiếp tục gỡ?'
        ApplyingCleanup       = 'Đang thực hiện gỡ...'
        ApplyingCleanupLog    = 'Đang gỡ với backup/quarantine...'
        CleanupCompleted      = 'Gỡ hoàn tất.'
        CleanupCompletedMsg   = 'Gỡ hoàn tất.`r`nThành công: {0}, Lỗi: {1}, Bỏ qua: {2}`r`n{3}'
        CleanupFailed         = 'Gỡ thất bại.'
        ApplyCleanupError     = 'Lỗi gỡ crack'
        ReadyLog              = 'Sẵn sàng. Bấm CHECK để quét và lưu report.'
    }
}

function Get-CLText { param([string]$Key) $script:text[$script:language][$Key] }

function New-CLDemoScanResult {
    $indicator = [pscustomobject]@{
        Type = 'OfficeCrackOhook'
        Name = 'Office Crack Ohook'
        Location = 'C:\Program Files\Microsoft Office\root\vfs\System\sppc.dll'
        Evidence = 'DEMO MODE: Non-Microsoft Office sppc hook DLL; SHA256=demo; Signature=NotSigned'
        Severity = 'High'
        IsSuspicious = $true
    }

    [pscustomobject]@{
        Tool            = 'check-license-demo'
        GeneratedAt     = (Get-Date).ToString('o')
        Compatibility   = [pscustomobject]@{ ComputerName = $env:COMPUTERNAME; OSName = 'Demo Windows'; BuildNumber = 22631; IsSupported = $true }
        WindowsLicenses = @([pscustomobject]@{ ProductName = 'Demo Windows Pro'; Description = 'RETAIL channel'; LicenseStatusText = 'Licensed'; PartialProductKey = 'DEMO1'; IsLicensed = $true })
        OfficeLicenses  = @([pscustomobject]@{ Source = 'Demo'; ProductName = 'Demo Microsoft Office'; LicenseStatusText = 'Licensed'; PartialProductKey = 'DEMO2'; ToolPath = $null; IsLicensed = $true })
        KmsInfo         = @()
        Indicators      = @($indicator)
        Risk            = [pscustomobject]@{ Score = 100; Level = 'High'; Category = 'Crack Detected'; Reasons = @('Office Crack Ohook detected', 'Demo data for cleanup UI testing') }
        Report          = $null
        IsDemo          = $true
    }
}

function Invoke-CLGuiScan {
    param([switch]$NoReport)

    if ($env:CHECKLICENSE_DEMO_CRACK -eq '1') { return New-CLDemoScanResult }

    $compatibility = Test-CLCompatibility
    $windowsLicenses = @(Get-CLWindowsLicense)
    $officeLicenses = @(Get-CLOfficeLicense)
    $kmsInfo = @(Get-CLKmsInfo -SuspiciousKeywords @($rules.suspiciousKmsKeywords))
    $baseIndicators = @(Get-CLCrackIndicators -IndicatorNames @($rules.indicatorNames) -IndicatorPaths @($rules.indicatorPaths))
    $advancedIndicators = @(Get-CLAdvancedActivationIndicators -Rules $rules -WindowsLicenses $windowsLicenses -OfficeLicenses $officeLicenses -KmsInfo $kmsInfo -ExistingIndicators $baseIndicators)
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

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Check License" Height="620" Width="920" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Background="#F5F6F8" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="34,13"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#0F6CBD"/>
            <Setter Property="BorderBrush" Value="#0F6CBD"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#D13438"/>
            <Setter Property="BorderBrush" Value="#D13438"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="18,10"/>
        </Style>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="0,0,12,12"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#E1E4E8"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#FFFFFF" BorderBrush="#E1E4E8" BorderThickness="0,0,0,1">
            <Grid Margin="22,14">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Border Width="40" Height="40" Background="#0F6CBD" CornerRadius="8" VerticalAlignment="Center">
                    <Viewbox Width="24" Height="24" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Canvas Width="24" Height="24">
                            <Rectangle Fill="White" Width="9" Height="9" Canvas.Left="2" Canvas.Top="2"/>
                            <Rectangle Fill="White" Width="9" Height="9" Canvas.Left="13" Canvas.Top="2"/>
                            <Rectangle Fill="White" Width="9" Height="9" Canvas.Left="2" Canvas.Top="13"/>
                            <Rectangle Fill="White" Width="9" Height="9" Canvas.Left="13" Canvas.Top="13"/>
                        </Canvas>
                    </Viewbox>
                </Border>
                <StackPanel Grid.Column="1" Margin="12,0,0,0">
                    <TextBlock x:Name="AppTitleText" Text="Check License" Foreground="#1F1F1F" FontSize="21" FontWeight="SemiBold"/>
                    <TextBlock x:Name="AppSubtitleText" Text="Windows and Office license compliance scanner" Foreground="#616161" FontSize="13"/>
                </StackPanel>
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" Margin="0,0,10,0">
                        <Button x:Name="EnglishButton" Content="EN" Tag="en" Width="44" Height="28" Padding="0" FontSize="13" ToolTip="English"/>
                        <Button x:Name="VietnameseButton" Content="VI" Tag="vi" Width="44" Height="28" Padding="0" FontSize="13" Margin="6,0,0,0" ToolTip="Tiếng Việt"/>
                    </StackPanel>
                    <Border x:Name="AdminBadge" Background="#FFF4CE" CornerRadius="15" Padding="12,5" VerticalAlignment="Center">
                        <TextBlock x:Name="AdminBadgeText" Text="STANDARD USER" Foreground="#8A6A00" FontWeight="SemiBold"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <Border Grid.Row="1" Background="#F3F2F1" BorderBrush="#D0D7DE" BorderThickness="0,0,0,1">
            <Grid Margin="22,13">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock x:Name="ReadyTitleText" Text="Ready to scan" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold"/>
                    <TextBlock x:Name="StatusText" Text="Click CHECK to scan Windows, Office, KMS settings, and common activation indicators." Foreground="#616161" FontSize="13" Margin="0,3,0,0"/>
                    <Grid Margin="0,9,18,0">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="48"/></Grid.ColumnDefinitions>
                        <ProgressBar x:Name="ProgressBar" Minimum="0" Maximum="100" Value="0" Height="8" Foreground="#0F6CBD" Background="#E1E4E8"/>
                        <TextBlock x:Name="ProgressText" Grid.Column="1" Text="0%" Foreground="#616161" HorizontalAlignment="Right" FontSize="12"/>
                    </Grid>
                </StackPanel>
                <Button x:Name="CheckButton" Grid.Column="1" Content="CHECK"/>
            </Grid>
        </Border>

        <Grid Grid.Row="2" Margin="22">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="1.15*"/>
                <ColumnDefinition Width="1*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2" Style="{StaticResource Card}" Margin="0,0,0,14">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel>
                        <TextBlock x:Name="OverviewText" Text="Overview" Foreground="#1F1F1F" FontSize="26" FontWeight="SemiBold"/>
                        <TextBlock x:Name="ModeText" Text="Scans Windows and Office license status.&#x0a;Checks KMS, services, tasks, registry, and files.&#x0a;Creates reports and safe cleanup plans." Foreground="#616161" FontSize="13" Margin="0,4,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                    <Border Grid.Column="1" Background="#F8FAFC" BorderBrush="#E1E4E8" BorderThickness="1" CornerRadius="10" Padding="16,12" Width="260">
                        <StackPanel>
                            <TextBlock x:Name="RiskLabelText" Text="Status" Foreground="#616161" FontSize="12"/>
                            <TextBlock x:Name="RiskText" Text="Not scanned" Foreground="#1F1F1F" FontSize="20" FontWeight="SemiBold" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" MaxWidth="228"/>
                            <TextBlock x:Name="ScoreText" Text="Waiting for CHECK" Foreground="#616161" FontSize="12" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" MaxWidth="228" Margin="0,2,0,0"/>
                            <TextBlock x:Name="ScopeText" Text="Scope: Not scanned" Foreground="#616161" FontSize="12" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" MaxWidth="228" Margin="0,8,0,0"/>
                            <TextBlock x:Name="ActionText" Text="Action: Run CHECK" Foreground="#616161" FontSize="12" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" MaxWidth="228" Margin="0,2,0,0"/>
                            <Button x:Name="CleanupPlanButton" Content="Review Cleanup Plan" Style="{StaticResource DangerButton}" Margin="0,10,0,0" Visibility="Collapsed" HorizontalAlignment="Stretch"/>
                            <Button x:Name="ApplyCleanupButton" Content="Apply Cleanup" Style="{StaticResource DangerButton}" Margin="0,8,0,0" Visibility="Collapsed" HorizontalAlignment="Stretch"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Border>

            <UniformGrid Grid.Row="1" Grid.Column="0" Columns="2" VerticalAlignment="Top">
                <Border Style="{StaticResource Card}"><StackPanel><TextBlock x:Name="WindowsLabelText" Text="Windows" Foreground="#616161"/><TextBlock x:Name="WindowsText" Text="Waiting" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/><Rectangle x:Name="WindowsBar" Height="3" Fill="#E1E4E8" Margin="0,12,0,0"/></StackPanel></Border>
                <Border Style="{StaticResource Card}"><StackPanel><TextBlock x:Name="OfficeLabelText" Text="Office" Foreground="#616161"/><TextBlock x:Name="OfficeText" Text="Waiting" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/><Rectangle x:Name="OfficeBar" Height="3" Fill="#E1E4E8" Margin="0,12,0,0"/></StackPanel></Border>
                <Border Style="{StaticResource Card}"><StackPanel><TextBlock x:Name="KmsLabelText" Text="KMS" Foreground="#616161"/><TextBlock x:Name="KmsText" Text="Waiting" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/><Rectangle x:Name="KmsBar" Height="3" Fill="#E1E4E8" Margin="0,12,0,0"/></StackPanel></Border>
                <Border Style="{StaticResource Card}"><StackPanel><TextBlock x:Name="IndicatorLabelText" Text="Indicators" Foreground="#616161"/><TextBlock x:Name="IndicatorText" Text="Waiting" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/><Rectangle x:Name="IndicatorBar" Height="3" Fill="#E1E4E8" Margin="0,12,0,0"/></StackPanel></Border>
            </UniformGrid>

            <Border Grid.Row="1" Grid.Column="1" Style="{StaticResource Card}" Margin="0,0,0,12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" x:Name="AuditDetailsText" Text="Audit details" Foreground="#1F1F1F" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBox Grid.Row="1" x:Name="DetailBox" Background="#FAFAFA" Foreground="#24292F" BorderBrush="#E1E4E8" BorderThickness="1" FontFamily="Consolas" FontSize="12" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" IsReadOnly="True" Padding="8"/>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = 'AppTitleText', 'AppSubtitleText', 'EnglishButton', 'VietnameseButton', 'ReadyTitleText', 'OverviewText', 'WindowsLabelText', 'OfficeLabelText', 'KmsLabelText', 'IndicatorLabelText', 'AuditDetailsText', 'RiskLabelText', 'RiskText', 'ScoreText', 'ScopeText', 'ActionText', 'WindowsText', 'OfficeText', 'KmsText', 'IndicatorText', 'WindowsBar', 'OfficeBar', 'KmsBar', 'IndicatorBar', 'DetailBox', 'CheckButton', 'StatusText', 'ProgressBar', 'ProgressText', 'CleanupPlanButton', 'ApplyCleanupButton', 'AdminBadge', 'AdminBadgeText', 'ModeText'
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Update-CLLanguageView {
    $window.Title = Get-CLText 'AppTitle'
    $script:AppTitleText.Text = Get-CLText 'AppTitle'
    $script:AppSubtitleText.Text = Get-CLText 'AppSubtitle'
    $script:ReadyTitleText.Text = Get-CLText 'ReadyTitle'
    $script:OverviewText.Text = Get-CLText 'Overview'
    $script:WindowsLabelText.Text = Get-CLText 'Windows'
    $script:OfficeLabelText.Text = Get-CLText 'Office'
    $script:KmsLabelText.Text = Get-CLText 'Kms'
    $script:IndicatorLabelText.Text = Get-CLText 'Indicators'
    $script:AuditDetailsText.Text = Get-CLText 'AuditDetails'
    $script:RiskLabelText.Text = Get-CLText 'Status'
    $script:CleanupPlanButton.Content = Get-CLText 'ReviewCleanupPlan'
    $script:ApplyCleanupButton.Content = Get-CLText 'ApplyCleanup'
    $script:EnglishButton.Opacity = if ($script:language -eq 'en') { 1.0 } else { 0.45 }
    $script:VietnameseButton.Opacity = if ($script:language -eq 'vi') { 1.0 } else { 0.45 }
    if (-not ($script:scanJob -and $script:scanJob.State -eq 'Running')) { $script:CheckButton.Content = Get-CLText 'Check' }
    if (-not $script:lastResult) {
        $script:StatusText.Text = Get-CLText 'ReadyStatus'
        $script:RiskText.Text = Get-CLText 'NotScanned'
        $script:ScoreText.Text = Get-CLText 'WaitingForCheck'
        $script:ScopeText.Text = 'Scope: Not scanned'
        $script:ActionText.Text = 'Action: Run CHECK'
        $script:WindowsText.Text = Get-CLText 'Waiting'
        $script:OfficeText.Text = Get-CLText 'Waiting'
        $script:KmsText.Text = Get-CLText 'Waiting'
        $script:IndicatorText.Text = Get-CLText 'Waiting'
    }
    else { Set-CLResultView -Result $script:lastResult }
    Set-CLAdminView
}

function Set-CLAdminView {
    $isAdmin = Test-CLAdmin
    $script:AdminBadge.Background = if ($isAdmin) { '#E8F5E9' } else { '#FFF4CE' }
    $script:AdminBadgeText.Foreground = if ($isAdmin) { '#107C10' } else { '#8A6A00' }
    $script:AdminBadgeText.Text = if ($isAdmin) { Get-CLText 'Administrator' } else { Get-CLText 'StandardUser' }
    $script:ModeText.Text = if ($isAdmin) { Get-CLText 'ModeAdmin' } else { Get-CLText 'ModeStandard' }
}

function Restart-CLAsAdmin {
    $scriptPath = Join-Path $PSScriptRoot 'main.ps1'
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$scriptPath`" -Gui"
    $window.Close()
}

function Set-CLProgress {
    param(
        [int]$Percent,
        [string]$Message
    )

    $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $script:ProgressBar.Value = $safePercent
    $script:ProgressText.Text = "$safePercent%"
    if ($Message) { $script:StatusText.Text = $Message }
}

function Convert-CLProgressMessage {
    param([string]$Message)

    switch ($Message) {
        'Checking compatibility...' { Get-CLText 'CheckingCompatibility'; break }
        'Checking Windows license...' { Get-CLText 'CheckingWindows'; break }
        'Checking Office license...' { Get-CLText 'CheckingOffice'; break }
        'Checking KMS configuration...' { Get-CLText 'CheckingKms'; break }
        'Checking activation indicators...' { Get-CLText 'CheckingIndicators'; break }
        'Calculating risk score...' { Get-CLText 'CalculatingRisk'; break }
        'Saving report...' { Get-CLText 'SavingReport'; break }
        default { $Message }
    }
}

function Add-CLLog {
    param([string]$Message)
    if ($script:DetailBox) {
        $script:DetailBox.AppendText("[$(Get-Date -Format HH:mm:ss)] $Message`r`n")
        $script:DetailBox.ScrollToEnd()
    }
}

function Add-CLSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)] [string]$Title
    )

    if ($Lines.Count -gt 0) { $Lines.Add('') }
    $Lines.Add($Title)
    $Lines.Add(('-' * $Title.Length))
}

function Format-CLValue {
    param([object]$Value, [string]$Fallback = 'N/A')
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $Fallback }
    [string]$Value
}

function Add-CLKeyValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)] [string]$Label,
        [object]$Value
    )

    $Lines.Add(('{0,-18}: {1}' -f $Label, (Format-CLValue $Value)))
}

function Set-CLDetailView {
    param([Parameter(Mandatory)] [object]$Result)

    $lines = New-Object System.Collections.Generic.List[string]
    Add-CLSection -Lines $lines -Title 'Tong quan'
    Add-CLKeyValue -Lines $lines -Label 'May tinh' -Value $Result.Compatibility.ComputerName
    Add-CLKeyValue -Lines $lines -Label 'He dieu hanh' -Value (('{0} build {1}' -f $Result.Compatibility.OSName, $Result.Compatibility.BuildNumber).Trim())
    Add-CLKeyValue -Lines $lines -Label 'Ho tro' -Value $Result.Compatibility.IsSupported
    Add-CLKeyValue -Lines $lines -Label 'Rui ro' -Value (('{0} / {1} / score {2}' -f $Result.Risk.Level, $Result.Risk.Category, $Result.Risk.Score).Trim())

    Add-CLSection -Lines $lines -Title 'Windows'
    $windows = @($Result.WindowsLicenses)
    if ($windows.Count -eq 0) { $lines.Add('Khong tim thay thong tin ban quyen Windows.') }
    foreach ($item in $windows) {
        Add-CLKeyValue -Lines $lines -Label 'Trang thai' -Value $item.LicenseStatusText
        Add-CLKeyValue -Lines $lines -Label 'San pham' -Value $item.ProductName
        Add-CLKeyValue -Lines $lines -Label 'Mo ta' -Value $item.Description
        Add-CLKeyValue -Lines $lines -Label 'Partial key' -Value $item.PartialProductKey
        if ($windows.Count -gt 1) { $lines.Add('') }
    }

    Add-CLSection -Lines $lines -Title 'Office'
    $office = @($Result.OfficeLicenses)
    if ($office.Count -eq 0) { $lines.Add('Khong tim thay thong tin ban quyen Office.') }
    foreach ($item in $office) {
        Add-CLKeyValue -Lines $lines -Label 'Trang thai' -Value $item.LicenseStatusText
        Add-CLKeyValue -Lines $lines -Label 'San pham' -Value $item.ProductName
        Add-CLKeyValue -Lines $lines -Label 'Nguon' -Value $item.Source
        Add-CLKeyValue -Lines $lines -Label 'Partial key' -Value $item.PartialProductKey
        if ($office.Count -gt 1) { $lines.Add('') }
    }

    Add-CLSection -Lines $lines -Title 'KMS'
    $kms = @($Result.KmsInfo | Where-Object { $_.IsConfigured -or $_.IsSuspicious })
    if ($kms.Count -eq 0) { $lines.Add('Khong phat hien cau hinh KMS dang chu y.') }
    foreach ($item in $kms) {
        Add-CLKeyValue -Lines $lines -Label 'Loai' -Value $item.Scope
        Add-CLKeyValue -Lines $lines -Label 'May chu' -Value $item.KeyManagementServiceName
        Add-CLKeyValue -Lines $lines -Label 'Cong' -Value $item.KeyManagementServicePort
        Add-CLKeyValue -Lines $lines -Label 'Dang ngo' -Value $item.IsSuspicious
        if ($item.Reason) { Add-CLKeyValue -Lines $lines -Label 'Ly do' -Value $item.Reason }
        if ($kms.Count -gt 1) { $lines.Add('') }
    }

    Add-CLSection -Lines $lines -Title 'Dau hieu bat thuong'
    $indicators = @($Result.Indicators | Where-Object { $_.IsSuspicious })
    if ($indicators.Count -eq 0) { $lines.Add('Khong phat hien dau hieu kich hoat bat thuong.') }
    foreach ($item in $indicators) {
        Add-CLKeyValue -Lines $lines -Label 'Loai' -Value $item.Type
        Add-CLKeyValue -Lines $lines -Label 'Muc do' -Value $item.Severity
        Add-CLKeyValue -Lines $lines -Label 'Ten' -Value $item.Name
        Add-CLKeyValue -Lines $lines -Label 'Vi tri' -Value $item.Location
        Add-CLKeyValue -Lines $lines -Label 'Bang chung' -Value $item.Evidence
        $lines.Add('')
    }

    Add-CLSection -Lines $lines -Title 'Ly do danh gia'
    $reasons = @($Result.Risk.Reasons | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($reasons.Count -eq 0) { $lines.Add('Khong co ly do rui ro dang chu y.') }
    foreach ($reason in $reasons) { $lines.Add("- $reason") }

    Add-CLSection -Lines $lines -Title 'Bao cao'
    if ($Result.Report -and $Result.Report.JsonPath) {
        Add-CLKeyValue -Lines $lines -Label 'Thu muc' -Value (Split-Path -Parent $Result.Report.JsonPath)
        $lines.Add('Bao cao da duoc luu de ky thuat vien doi chieu khi can.')
    }
    else {
        $lines.Add('Khong tao bao cao trong lan quet nay.')
    }

    $script:DetailBox.Text = ($lines -join "`r`n")
}

function Get-CLDirectCrackConclusion {
    param([object[]]$Indicators)

    $direct = @($Indicators | Where-Object { $_.IsSuspicious -and $_.Type -in @('OfficeCrackOhook', 'SppStoreTsforge', 'WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder') })
    $hasOffice = @($direct | Where-Object { $_.Type -eq 'OfficeCrackOhook' }).Count -gt 0
    $hasWindows = @($direct | Where-Object { $_.Type -in @('SppStoreTsforge', 'WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder') }).Count -gt 0

    if ($hasWindows -and $hasOffice) { return 'Windows + Office Crack' }
    if (@($direct | Where-Object { $_.Type -eq 'SppStoreTsforge' }).Count -gt 0) { return 'Windows/Office Crack TSforge' }
    if ($hasWindows) { return 'Windows Crack HWID' }
    if ($hasOffice) { return 'Office Crack Ohook' }
    return $null
}

function Set-CLResultView {
    param([object]$Result)

    $win = @($Result.WindowsLicenses | Select-Object -First 1)
    $off = @($Result.OfficeLicenses | Select-Object -First 1)
    $kmsSuspicious = @($Result.KmsInfo | Where-Object { $_.IsSuspicious }).Count
    $indicatorCount = @($Result.Indicators | Where-Object { $_.IsSuspicious }).Count
    $windowsLicensed = ($win -and $win[0].IsLicensed)
    $officeLicensed = ($off -and $off[0].IsLicensed)
    $hasCrackSignal = ($kmsSuspicious -gt 0 -or $indicatorCount -gt 0)
    $directConclusion = Get-CLDirectCrackConclusion -Indicators @($Result.Indicators)

    $script:RiskLabelText.Text = Get-CLText 'Status'
    $script:RiskText.Text = if ($directConclusion) { $directConclusion } elseif ($hasCrackSignal) { Get-CLText 'UninstallSafe' } else { Get-CLText 'Passed' }
    $script:ScoreText.Text = if ($hasCrackSignal) { "$(Get-CLText 'CleanupAvailable') | $kmsSuspicious KMS | $indicatorCount indicator(s)" } else { Get-CLText 'NoCrackDetected' }
    $hasWindowsCrack = @($Result.Indicators | Where-Object { $_.IsSuspicious -and ($_.Type -in @('SppStoreTsforge', 'WindowsCrackHWIDFile', 'WindowsCrackHWIDFolder') -or $_.Name -match 'HWID|KMS38|TSforge|MAS') }).Count -gt 0
    $hasOfficeCrack = @($Result.Indicators | Where-Object { $_.IsSuspicious -and $_.Type -in @('OfficeCrackOhook', 'OfficeProtectionRegistry') }).Count -gt 0
    $scope = if ($hasWindowsCrack -and $hasOfficeCrack) { 'Windows + Office affected' } elseif ($hasWindowsCrack) { 'Windows affected' } elseif ($hasOfficeCrack) { 'Office affected' } elseif ($hasCrackSignal) { 'Activation traces found' } else { 'No affected product' }
    $action = if ($hasCrackSignal) { 'Ready to clean activation' } else { 'No cleanup needed' }
    $script:ScopeText.Text = "Scope: $scope"
    $script:ActionText.Text = "Action: $action"
    $script:ScopeText.Foreground = if ($hasCrackSignal) { '#D13438' } else { '#107C10' }
    $script:ActionText.Foreground = if ($hasCrackSignal) { '#D13438' } else { '#107C10' }
    $script:RiskText.Foreground = if ($hasCrackSignal) { '#D13438' } else { '#107C10' }

    $script:WindowsText.Text = if ($windowsLicensed) { Get-CLText 'Licensed' } elseif ($win) { Get-CLText 'DetectCracked' } else { Get-CLText 'DetectCracked' }
    $script:OfficeText.Text = if ($officeLicensed) { Get-CLText 'Licensed' } elseif ($off) { Get-CLText 'DetectCracked' } else { Get-CLText 'DetectCracked' }
    $script:KmsText.Text = if ($kmsSuspicious -gt 0) { "$kmsSuspicious $(Get-CLText 'Suspicious')" } else { Get-CLText 'NoSuspiciousKms' }
    $script:IndicatorText.Text = if ($indicatorCount -gt 0) { "$indicatorCount $(Get-CLText 'Found')" } else { Get-CLText 'NoIndicator' }

    $script:WindowsText.Foreground = if ($windowsLicensed) { '#107C10' } else { '#D13438' }
    $script:OfficeText.Foreground = if ($officeLicensed) { '#107C10' } else { '#D13438' }
    $script:KmsText.Foreground = if ($kmsSuspicious -gt 0) { '#D13438' } else { '#0F6CBD' }
    $script:IndicatorText.Foreground = if ($indicatorCount -gt 0) { '#D13438' } else { '#0F6CBD' }
    $script:WindowsBar.Fill = if ($windowsLicensed) { '#107C10' } else { '#D13438' }
    $script:OfficeBar.Fill = if ($officeLicensed) { '#107C10' } else { '#D13438' }
    $script:KmsBar.Fill = if ($kmsSuspicious -gt 0) { '#D13438' } else { '#0F6CBD' }
    $script:IndicatorBar.Fill = if ($indicatorCount -gt 0) { '#D13438' } else { '#0F6CBD' }
    $script:CleanupPlanButton.Visibility = if ($hasCrackSignal) { 'Visible' } else { 'Collapsed' }
    $script:ApplyCleanupButton.Visibility = if ($hasCrackSignal) { 'Visible' } else { 'Collapsed' }

    Set-CLDetailView -Result $Result
}

function Start-CLGuiScan {
    param([switch]$NoReport)

    try {
        if ($script:scanJob -and $script:scanJob.State -eq 'Running') { return }

        $script:CheckButton.IsEnabled = $false
        $script:CheckButton.Content = Get-CLText 'Checking'
        Set-CLProgress -Percent 3 -Message (Get-CLText 'PreparingScan')
        Add-CLLog (Get-CLText 'StartingScan')

        $script:scanJob = Start-Job -ArgumentList $moduleRoot, $rulesPath, $false -ScriptBlock {
            param($ModuleRoot, $RulesPath, $NoReport)

            foreach ($module in @('Compatibility', 'WindowsLicense', 'VNextLicense', 'OfficeLicense', 'KmsScanner', 'CrackIndicatorScanner', 'AdvancedActivationScanner', 'RiskScore', 'Report', 'CleanupPlan', 'CleanupApply')) {
                Import-Module (Join-Path $ModuleRoot "$module.psm1") -Force -ErrorAction Stop
            }

            $rules = Get-Content -LiteralPath $RulesPath -Raw -ErrorAction Stop | ConvertFrom-Json

            if ($env:CHECKLICENSE_DEMO_CRACK -eq '1') {
                [pscustomobject]@{ Kind = 'Progress'; Percent = 90; Message = 'Calculating risk score...' }
                $indicator = [pscustomobject]@{ Type = 'OfficeCrackOhook'; Name = 'Office Crack Ohook'; Location = 'C:\Program Files\Microsoft Office\root\vfs\System\sppc.dll'; Evidence = 'DEMO MODE: Non-Microsoft Office sppc hook DLL; SHA256=demo; Signature=NotSigned'; Severity = 'High'; IsSuspicious = $true }
                $result = [pscustomobject]@{
                    Tool            = 'check-license-demo'
                    GeneratedAt     = (Get-Date).ToString('o')
                    Compatibility   = [pscustomobject]@{ ComputerName = $env:COMPUTERNAME; OSName = 'Demo Windows'; BuildNumber = 22631; IsSupported = $true }
                    WindowsLicenses = @([pscustomobject]@{ ProductName = 'Demo Windows Pro'; Description = 'RETAIL channel'; LicenseStatusText = 'Licensed'; PartialProductKey = 'DEMO1'; IsLicensed = $true })
                    OfficeLicenses  = @([pscustomobject]@{ Source = 'Demo'; ProductName = 'Demo Microsoft Office'; LicenseStatusText = 'Licensed'; PartialProductKey = 'DEMO2'; ToolPath = $null; IsLicensed = $true })
                    KmsInfo         = @()
                    Indicators      = @($indicator)
                    Risk            = [pscustomobject]@{ Score = 100; Level = 'High'; Category = 'Crack Detected'; Reasons = @('Office Crack Ohook detected', 'Demo data for cleanup UI testing') }
                    Report          = $null
                    IsDemo          = $true
                }
                [pscustomobject]@{ Kind = 'Result'; Data = $result }
                return
            }

            [pscustomobject]@{ Kind = 'Progress'; Percent = 8; Message = 'Checking compatibility...' }
            $compatibility = Test-CLCompatibility
            [pscustomobject]@{ Kind = 'Progress'; Percent = 22; Message = 'Checking Windows license...' }
            $windowsLicenses = @(Get-CLWindowsLicense)
            [pscustomobject]@{ Kind = 'Progress'; Percent = 45; Message = 'Checking Office license...' }
            $officeLicenses = @(Get-CLOfficeLicense)
            [pscustomobject]@{ Kind = 'Progress'; Percent = 62; Message = 'Checking KMS configuration...' }
            $kmsInfo = @(Get-CLKmsInfo -SuspiciousKeywords @($rules.suspiciousKmsKeywords))
            [pscustomobject]@{ Kind = 'Progress'; Percent = 78; Message = 'Checking activation indicators...' }
            $baseIndicators = @(Get-CLCrackIndicators -IndicatorNames @($rules.indicatorNames) -IndicatorPaths @($rules.indicatorPaths))
            $advancedIndicators = @(Get-CLAdvancedActivationIndicators -Rules $rules -WindowsLicenses $windowsLicenses -OfficeLicenses $officeLicenses -KmsInfo $kmsInfo -ExistingIndicators $baseIndicators)
            $indicators = @($baseIndicators + $advancedIndicators)
            [pscustomobject]@{ Kind = 'Progress'; Percent = 90; Message = 'Calculating risk score...' }
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

            [pscustomobject]@{ Kind = 'Progress'; Percent = 96; Message = 'Saving report...' }
            $result.Report = New-CLReport -Data $result -NoReport:$NoReport
            [pscustomobject]@{ Kind = 'Result'; Data = $result }
        }

        if ($script:progressTimer) { $script:progressTimer.Stop() }
        $script:progressTimer = New-Object Windows.Threading.DispatcherTimer
        $script:progressTimer.Interval = [TimeSpan]::FromMilliseconds(180)
        $script:progressTimer.Add_Tick({
                try {
                    if (-not $script:scanJob) { return }
                    $items = @(Receive-Job -Job $script:scanJob -Keep -ErrorAction SilentlyContinue)
                    foreach ($item in $items) {
                        if ($item.Kind -eq 'Progress') { Set-CLProgress -Percent $item.Percent -Message (Convert-CLProgressMessage $item.Message) }
                        elseif ($item.Kind -eq 'Result') { $script:lastResult = $item.Data }
                    }

                    if ($script:scanJob.State -in @('Completed', 'Failed', 'Stopped')) {
                        $script:progressTimer.Stop()
                        $items = @(Receive-Job -Job $script:scanJob -ErrorAction SilentlyContinue)
                        foreach ($item in $items) {
                            if ($item.Kind -eq 'Progress') { Set-CLProgress -Percent $item.Percent -Message (Convert-CLProgressMessage $item.Message) }
                            elseif ($item.Kind -eq 'Result') { $script:lastResult = $item.Data }
                        }

                        if ($script:scanJob.State -eq 'Completed' -and $script:lastResult) {
                            Set-CLProgress -Percent 100 -Message (Get-CLText 'ScanCompleted')
                            Set-CLResultView -Result $script:lastResult
                            Add-CLLog (Get-CLText 'ScanCompleted')
                            if ($script:lastResult.Report) { Add-CLLog 'Report saved.' }
                        }
                        else {
                            Set-CLProgress -Percent 0 -Message (Get-CLText 'ScanFailed')
                            Add-CLLog 'ERROR: background scan failed.'
                        }

                        Remove-Job -Job $script:scanJob -Force -ErrorAction SilentlyContinue
                        $script:scanJob = $null
                        $script:CheckButton.IsEnabled = $true
                        $script:CheckButton.Content = Get-CLText 'Check'
                        if ($script:lastResult) { $script:StatusText.Text = Get-CLText 'ScanCompleted' }
                    }
                }
                catch {
                    Add-CLLog "ERROR: $($_.Exception.Message)"
                }
            })
        $script:progressTimer.Start()
    }
    catch {
        Add-CLLog "ERROR: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Check License error', 'OK', 'Error') | Out-Null
        $script:CheckButton.IsEnabled = $true
        $script:CheckButton.Content = Get-CLText 'Check'
    }
}

$CheckButton.Add_Click({ Start-CLGuiScan })
$EnglishButton.Add_Click({ $script:language = 'en'; Update-CLLanguageView })
$VietnameseButton.Add_Click({ $script:language = 'vi'; Update-CLLanguageView })
$CleanupPlanButton.Add_Click({
        if (-not $script:lastResult) {
            [System.Windows.MessageBox]::Show((Get-CLText 'RunCheckFirstPlan'), (Get-CLText 'CleanupAssistant'), 'OK', 'Information') | Out-Null
            return
        }

        $plan = New-CLCleanupPlan -ScanResult $script:lastResult
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add((Get-CLText 'CleanupDryRun'))
        $lines.Add('=' * 28)
        $lines.Add((Get-CLText 'DryRunNoChange'))
        $lines.Add('')
        $lines.Add("Ket luan: $($script:lastResult.Risk.Category) / $($script:lastResult.Risk.Level) / score $($script:lastResult.Risk.Score)")
        $lines.Add('')
        $lines.Add('Nguyen nhan ket luan')
        $lines.Add('-------------------')
        foreach ($reason in @($script:lastResult.Risk.Reasons)) { $lines.Add("- $reason") }
        $lines.Add('')
        $lines.Add('Bang chung')
        $lines.Add('----------')
        foreach ($indicator in @($script:lastResult.Indicators | Where-Object { $_.IsSuspicious })) {
            $lines.Add("[$($indicator.Severity)] $($indicator.Name) ($($indicator.Type))")
            $lines.Add("Vi tri    : $($indicator.Location)")
            $lines.Add("Bang chung: $($indicator.Evidence)")
            $lines.Add('')
        }
        $lines.Add('Hanh dong khi bam Go crack')
        $lines.Add('--------------------------')
        $lines.Add($plan.RestartNotice)
        $lines.Add('')
        foreach ($action in @($plan.Actions)) {
            $lines.Add("[$($action.Id)] $($action.Category) | $($action.Risk)")
            $lines.Add("Action : $($action.Action)")
            $lines.Add("Target : $($action.Target)")
            $lines.Add("Reason : $($action.Reason)")
            $lines.Add("Preview: $($action.CommandPreview)")
            $lines.Add('')
        }

        $script:DetailBox.Text = ($lines -join "`r`n")
        Add-CLLog (Get-CLText 'DryRunGenerated')
        [System.Windows.MessageBox]::Show((Get-CLText 'DryRunGenerated'), (Get-CLText 'CleanupDryRun'), 'OK', 'Information') | Out-Null
    })

$ApplyCleanupButton.Add_Click({
        if (-not $script:lastResult) {
            [System.Windows.MessageBox]::Show((Get-CLText 'RunCheckFirstApply'), (Get-CLText 'ApplyCleanup'), 'OK', 'Information') | Out-Null
            return
        }

        $plan = New-CLCleanupPlan -ScanResult $script:lastResult
        if ($script:lastResult.IsDemo) {
            $plan = [pscustomobject]@{
                RestartNotice = 'DEMO MODE: No restart is required because no system changes will be made.'
                Actions = @(
                    [pscustomobject]@{ Id = 'DEMO-1'; Category = 'OfficeCrackOhook'; Name = 'Office Crack Ohook'; Action = 'Quarantine hook DLL'; Target = 'C:\Program Files\Microsoft Office\root\vfs\System\sppc.dll'; Reason = 'Demo Ohook DLL indicator'; CommandPreview = 'Move DLL to quarantine'; Risk = 'High'; RestartRecommended = $true; RestartReason = 'Restart Office after removing hook DLL.' },
                    [pscustomobject]@{ Id = 'DEMO-2'; Category = 'OfficeActivationReset'; Name = 'Office license cache'; Action = 'Reset Office activation cache'; Target = 'Current user Office licensing cache'; Reason = 'Demo reset Office activation state'; CommandPreview = 'Remove Office tokens and credentials'; Risk = 'High'; RestartRecommended = $true; RestartReason = 'Restart Office after resetting activation cache.' }
                )
            }
        }
        if (@($plan.Actions).Count -eq 0) {
            [System.Windows.MessageBox]::Show((Get-CLText 'NoActions'), (Get-CLText 'ApplyCleanup'), 'OK', 'Information') | Out-Null
            return
        }

        if (-not (Test-CLAdmin)) {
            $confirmAdmin = [System.Windows.MessageBox]::Show((Get-CLText 'AdminRequired'), (Get-CLText 'AdminRequiredTitle'), 'OKCancel', 'Warning')
            if ($confirmAdmin -eq 'OK') { Restart-CLAsAdmin }
            return
        }

        $message = (Get-CLText 'ConfirmApply') -f @($plan.Actions).Count, $plan.RestartNotice
        $confirm = [System.Windows.MessageBox]::Show($message, (Get-CLText 'ConfirmApplyTitle'), 'YesNo', 'Question')
        if ($confirm -ne 'Yes') { return }

        try {
            $script:ApplyCleanupButton.IsEnabled = $false
            $script:CleanupPlanButton.IsEnabled = $false
            Set-CLProgress -Percent 5 -Message (Get-CLText 'ApplyingCleanup')
            Add-CLLog (Get-CLText 'ApplyingCleanupLog')

            if ($script:lastResult.IsDemo) {
                $applyResult = [pscustomobject]@{
                    GeneratedAt        = (Get-Date).ToString('o')
                    SessionRoot        = 'DEMO MODE - no files were created'
                    BackupRoot         = 'DEMO MODE - no registry backup was created'
                    QuarantineRoot     = 'DEMO MODE - no quarantine was created'
                    AppliedCount       = 2
                    FailedCount        = 0
                    SkippedCount       = 0
                    RestartRecommended = $true
                    RestartNotice      = 'DEMO MODE: This is a UI preview only. No Windows or Office licensing data was changed.'
                    LogPath            = 'DEMO MODE - no log file was written'
                    Results            = @(
                        [pscustomobject]@{ Id = 'DEMO-1'; Category = 'OfficeCrackOhook'; Name = 'Office Crack Ohook'; Action = 'Quarantine hook DLL'; Target = 'C:\Program Files\Microsoft Office\root\vfs\System\sppc.dll'; Status = 'Applied'; Message = 'Demo quarantine completed.'; BackupPath = $null; QuarantinePath = 'DEMO MODE - quarantine path preview'; RestartRecommended = $true; RestartReason = 'Restart Office after removing hook DLL.' },
                        [pscustomobject]@{ Id = 'DEMO-2'; Category = 'OfficeActivationReset'; Name = 'Office license cache'; Action = 'Reset Office activation cache'; Target = 'Current user Office licensing cache'; Status = 'Applied'; Message = 'Demo Office activation cache reset completed.'; BackupPath = 'DEMO MODE - registry backup preview'; QuarantinePath = 'DEMO MODE - token cache quarantine preview'; RestartRecommended = $true; RestartReason = 'Restart Office after resetting activation cache.' }
                    )
                }
            }
            else {
                $applyResult = Invoke-CLCleanupPlan -Plan $plan -Force
            }
            Set-CLProgress -Percent 100 -Message (Get-CLText 'CleanupCompleted')

            $lines = New-Object System.Collections.Generic.List[string]
            $overallStatus = if ($applyResult.FailedCount -gt 0) { 'COMPLETED WITH ERRORS' } elseif ($applyResult.SkippedCount -gt 0) { 'COMPLETED WITH WARNINGS' } else { 'COMPLETED SUCCESSFULLY' }
            $lines.Add('GO CRACK - CLEANUP RESULT')
            $lines.Add('=' * 58)
            $lines.Add("Status      : $overallStatus")
            $lines.Add("Completed   : $($applyResult.GeneratedAt)")
            $lines.Add("Applied     : $($applyResult.AppliedCount)")
            $lines.Add("Failed      : $($applyResult.FailedCount)")
            $lines.Add("Skipped     : $($applyResult.SkippedCount)")
            $lines.Add("Restart     : $($applyResult.RestartNotice)")
            $lines.Add('')
            $lines.Add('Storage')
            $lines.Add('-------')
            $lines.Add("Cleanup log : $($applyResult.LogPath)")
            $lines.Add("Backup root : $($applyResult.BackupRoot)")
            $lines.Add("Quarantine  : $($applyResult.QuarantineRoot)")
            $lines.Add('')
            $lines.Add('Actions')
            $lines.Add('-------')
            foreach ($item in @($applyResult.Results)) {
                $marker = switch ($item.Status) {
                    'Applied' { '[OK]' }
                    'Failed' { '[FAILED]' }
                    'Skipped' { '[SKIPPED]' }
                    default { "[$($item.Status)]" }
                }
                $lines.Add("$marker $($item.Id)  $($item.Category)  $($item.Name)")
                $lines.Add("  Action : $($item.Action)")
                $lines.Add("  Target : $($item.Target)")
                $lines.Add("  Result : $($item.Message)")
                if ($item.BackupPath) { $lines.Add("  Backup : $($item.BackupPath)") }
                if ($item.QuarantinePath) { $lines.Add("  Quarantine: $($item.QuarantinePath)") }
                if ($item.RestartRecommended) { $lines.Add("  Restart: $($item.RestartReason)") }
                $lines.Add('')
            }
            $lines.Add('Next steps')
            $lines.Add('----------')
            if ($applyResult.RestartRecommended) { $lines.Add('- Restart Windows, then run CHECK again to confirm Windows/Office are clean.') }
            else { $lines.Add('- Run CHECK again to confirm no crack indicators remain.') }
            if ($applyResult.FailedCount -gt 0) { $lines.Add('- Review failed actions above and run the app as Administrator if needed.') }
            if ($applyResult.SkippedCount -gt 0) { $lines.Add('- Skipped actions are intentionally left for manual review, usually SPP store safety cases.') }

            $script:DetailBox.Text = ($lines -join "`r`n")
            Add-CLLog "Cleanup completed. Applied=$($applyResult.AppliedCount), Failed=$($applyResult.FailedCount), Skipped=$($applyResult.SkippedCount), Log=$($applyResult.LogPath)"
            $cleanupMessage = "Gỡ crack hoàn tất.`r`n`r`nTrạng thái: $overallStatus`r`nThành công: $($applyResult.AppliedCount)`r`nLỗi: $($applyResult.FailedCount)`r`nBỏ qua: $($applyResult.SkippedCount)`r`n`r`n$($applyResult.RestartNotice)"
            [System.Windows.MessageBox]::Show($cleanupMessage, (Get-CLText 'ApplyCleanup'), 'OK', 'Information') | Out-Null
        }
        catch {
            Set-CLProgress -Percent 0 -Message (Get-CLText 'CleanupFailed')
            Add-CLLog "ERROR: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show($_.Exception.Message, (Get-CLText 'ApplyCleanupError'), 'OK', 'Error') | Out-Null
        }
        finally {
            $script:ApplyCleanupButton.IsEnabled = $true
            $script:CleanupPlanButton.IsEnabled = $true
        }
    })

Update-CLLanguageView
Add-CLLog (Get-CLText 'ReadyLog')
$window.ShowDialog() | Out-Null





