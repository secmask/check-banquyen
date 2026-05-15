[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$NoReport,
    [switch]$KeepFiles,
    [switch]$VerboseLog,
    [switch]$Gui,
    [switch]$CreateShortcut,
    [string]$ReleaseUrl = 'https://github.com/mson-ssh/check-banquyen/archive/refs/heads/main.zip'
)

$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:TEMP 'check-license'
$zipPath = Join-Path $env:TEMP 'check-license.zip'

function Start-CLInstalledTool {
    param(
        [string]$MainPath,
        [bool]$RunGui,
        [bool]$RunJson,
        [bool]$SkipReport,
        [bool]$UseVerbose
    )

    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$MainPath`"")
    if ($RunGui) { $arguments += '-Gui' }
    if ($RunJson) { $arguments += '-Json' }
    if ($SkipReport) { $arguments += '-NoReport' }
    if ($UseVerbose) { $arguments += '-VerboseLog' }

    Start-Process powershell.exe -ArgumentList ($arguments -join ' ') | Out-Null
}

try {
    New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

    Write-Verbose "Downloading $ReleaseUrl"
    Invoke-WebRequest -Uri $ReleaseUrl -OutFile $zipPath -UseBasicParsing


    Expand-Archive -LiteralPath $zipPath -DestinationPath $installRoot -Force

    $main = Join-Path $installRoot 'src\main.ps1'
    if (-not (Test-Path -LiteralPath $main -PathType Leaf)) {
        $nested = Get-ChildItem -Path $installRoot -Filter main.ps1 -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like '*\src\main.ps1' } | Select-Object -First 1
        if ($nested) {
            $main = $nested.FullName
            $installRoot = Split-Path -Parent (Split-Path -Parent $main)
        }
    }

    if (-not (Test-Path -LiteralPath $main -PathType Leaf)) {
        throw 'src\main.ps1 was not found after extraction.'
    }

    $launcher = Join-Path $installRoot 'Check-License.cmd'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
        $launcherContent = @(
            '@echo off',
            'setlocal',
            'set "ROOT=%~dp0"',
            'start "Check License" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%ROOT%src\main.ps1" -Gui'
        ) -join "`r`n"
        Set-Content -LiteralPath $launcher -Value $launcherContent -Encoding ASCII
    }

    if ($CreateShortcut) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktop 'Check License.lnk'
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $launcher
        $shortcut.WorkingDirectory = $installRoot
        $shortcut.Description = 'Check Windows and Office license status'
        $shortcut.Save()
        Write-Host "Shortcut created: $shortcutPath"
    }

    if ($Gui) {
        Start-CLInstalledTool -MainPath $main -RunGui $true -RunJson $false -SkipReport $NoReport -UseVerbose $VerboseLog
        Write-Host 'Check License GUI is starting...'
    }
    else {
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$main`"")
        if ($Json) { $arguments += '-Json' }
        if ($NoReport) { $arguments += '-NoReport' }
        if ($VerboseLog) { $arguments += '-VerboseLog' }
        & powershell.exe @arguments
    }
}
catch {
    Write-Error "Install or scan failed: $($_.Exception.Message)"
    exit 1
}
finally {
    if (-not $KeepFiles -and (Test-Path -LiteralPath $zipPath)) {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    }
}