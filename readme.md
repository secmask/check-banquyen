# check-license

Read-only PowerShell compliance scanner for checking Windows and Microsoft Office license status on Windows 10 21H2+ and Windows 11.

## Features

- Checks Windows activation via `Get-CimInstance SoftwareLicensingProduct`.
- Checks Office 2016/2019/2021/2024, Microsoft 365 Apps, and LTSC via `vnextdiag.ps1` or `OSPP.VBS`.
- Reads KMS configuration from registry in read-only mode.
- Detects suspicious activation indicators via services, service paths, scheduled tasks, Run keys, IFEO debugger hooks, Office protection registry values, and known activation-tool paths.
- Exports JSON and CSV reports to `%ProgramData%\CheckLicense\reports`.
- Provides a console menu for quick scans, full scans, JSON output, and report access.
- Provides a clean, fixed-size WPF dashboard with a single `CHECK` button.

The tool does not check Windows Defender, read Defender history, modify the system, activate products, change keys, or use `wmic.exe`.

## Quick Start

```powershell
irm https://raw.githubusercontent.com/YOUR_USER/check-license/main/install.ps1 | iex
```

Run from local source. By default, this opens the console menu:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\main.ps1
```

Open the WPF dashboard:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\src\main.ps1 -Gui
```

The WPF dashboard uses a compact Office-style layout:

- Fixed-size window; resizing is disabled.
- Single `CHECK` button to scan Windows, Office, KMS, and common activation indicators.
- Risk summary card with level and score.
- Four status cards: Windows, Office, KMS, and Indicators.
- Audit details and activity log panels.
- JSON/CSV report paths are shown after the check completes.

## License Check Sources

The tool only uses read-only sources from the Windows and Office licensing stack:

- Windows activation: reads the CIM/WMI class `SoftwareLicensingProduct`, part of Software Protection Platform (SPP). Important fields include `Name`, `Description`, `LicenseStatus`, `PartialProductKey`, and `GracePeriodRemaining`. `LicenseStatus = 1` is treated as Licensed; other values are mapped to Unlicensed/Grace/Notification/Unknown.
- Windows KMS client info: reads `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform` for `KeyManagementServiceName` and `KeyManagementServicePort`.
- Office volume/perpetual licensing: prefers `OSPP.VBS /dstatus` in official Office15/Office16 folders. The output provides LICENSE NAME, LICENSE STATUS, and the last five product-key characters only. Full keys are never read or exported.
- Microsoft 365 Apps/vNext licensing: prefers `vnextdiag.ps1 -action list` when available in the Office root folder.
- Office Click-to-Run retail licensing: reads `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` and `HKCU:\Software\Microsoft\Office\16.0\Common\Licensing\LicensingNext` to detect retail products such as Microsoft Office Home and Student 2021.
- Office KMS registry: reads `HKLM:\SOFTWARE\WOW6432Node\Microsoft\OfficeSoftwareProtectionPlatform` for Office KMS host and port values.
- Indicator scanner: checks only read-only persistence and configuration locations: services, service executable paths, scheduled tasks/actions, Run keys, Image File Execution Options debugger hooks, Office protection registry values, and known file/folder paths.
- Covered activation-tool families include KMS emulators/clients (`AutoKMS`, `KMSpico`, `KMSAuto`, `vlmcsd`, `KMS_VL_ALL`), Microsoft Activation Scripts labels (`MAS`, `HWID`, `Ohook`, `TSforge`, `Online KMS`, `KMS38`), and common hook files such as `SppExtComObjHook.dll`.
- The scanner does not recursively scan full drives, does not remove files, and does not execute activation tools.

Note: the risk score is a basic compliance signal. It does not conclude “crack” or “illegal”.

The console menu includes:

- `1` Quick scan and summary, without writing a report.
- `2` Full scan and JSON/CSV report.
- `3` Print JSON to console.
- `4` View the latest JSON report.
- `5` Open the report folder.
- `0` Exit.

Print JSON to console without writing a report:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\main.ps1 -Json -NoReport
```

## Parameters

- `-Json`: prints JSON to console.
- `-NoReport`: skips JSON/CSV report files.
- `-VerboseLog`: enables verbose logging.
- `-Menu`: forces the interactive console menu.
- `-Gui`: opens the WPF dashboard.
- `install.ps1 -KeepFiles`: keeps the downloaded zip in `%TEMP%`.

## Build release

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1
```

Upload `check-license.zip` to GitHub Releases and replace `YOUR_USER` in `install.ps1` and documentation URLs.