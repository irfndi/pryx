<#
.SYNOPSIS
    Uninstall pryx on Windows.
.DESCRIPTION
    Removes the per-user launcher at %LOCALAPPDATA%\pryx\bin\pryx.exe,
    installed build binaries, and the pryx launcher directory from the user PATH.
    By default user data under %USERPROFILE%\.pryx is kept.

    One-liner uninstall:
      irm https://raw.githubusercontent.com/pryx-co/pryx/master/scripts/uninstall.ps1 | iex
.PARAMETER InstallDir
    Override the launcher directory (default: $env:LOCALAPPDATA\pryx\bin)
.PARAMETER Purge
    Also delete user data in $env:PRYX_HOME or %USERPROFILE%\.pryx.
.PARAMETER DryRun
    Print what would be removed without deleting anything.
.PARAMETER Yes
    Skip the confirmation prompt.
#>
param(
    [string]$InstallDir,
    [switch]$Purge,
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host $msg -ForegroundColor Blue }
function Write-Err($msg) { throw "error: $msg" }
function Write-Warn($msg) { Write-Host "warning: $msg" -ForegroundColor Yellow }

function Get-PryxLocalAppDataDir {
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }

    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ($localAppData) { return $localAppData }

    if ($env:USERPROFILE) { return (Join-Path $env:USERPROFILE "AppData\Local") }
    return (Join-Path ([Environment]::GetFolderPath("UserProfile")) "AppData\Local")
}

function Get-DefaultPryxInstallDir {
    return (Join-Path (Get-PryxLocalAppDataDir) "pryx\bin")
}

function Get-PryxRoamingAppDataDir {
    if ($env:APPDATA) { return $env:APPDATA }

    $appData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if ($appData) { return $appData }

    if ($env:USERPROFILE) { return (Join-Path $env:USERPROFILE "AppData\Roaming") }
    return (Join-Path ([Environment]::GetFolderPath("UserProfile")) "AppData\Roaming")
}

function Get-PryxStartupShortcutPath {
    return (Join-Path (Get-PryxRoamingAppDataDir) "Microsoft\Windows\Start Menu\Programs\Startup\pryx-hotkey.lnk")
}

function Get-PryxHotkeyArtifactPaths([string]$UserDataDir) {
    $hotkeyDir = Join-Path $UserDataDir "hotkey"
    return @(
        (Join-Path $hotkeyDir "pryx-hotkey.ps1"),
        (Join-Path $hotkeyDir "pryx-hotkey-launcher.vbs"),
        (Join-Path $hotkeyDir "pryx-hotkey-shortcut.ps1")
    )
}

function Clear-PryxHotkeySetupState([string]$UserDataDir) {
    $setupHintsPath = Join-Path $UserDataDir "setup_hints.json"
    if (-not (Test-Path -LiteralPath $setupHintsPath)) { return }

    try {
        $state = Get-Content -LiteralPath $setupHintsPath -Raw | ConvertFrom-Json -ErrorAction Stop
        foreach ($property in @(
            @{ Name = "hotkey_configured"; Value = $false },
            @{ Name = "hotkey_dismissed"; Value = $true }
        )) {
            if ($state.PSObject.Properties.Name -contains $property.Name) {
                $state.($property.Name) = $property.Value
            } else {
                $state | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
            }
        }
        $state | ConvertTo-Json | Set-Content -LiteralPath $setupHintsPath -Encoding UTF8
    } catch {
        Write-Warn "Could not update hotkey setup state in $setupHintsPath"
    }
}

function ConvertTo-PryxPathKey([string]$PathValue) {
    if (-not $PathValue) { return "" }
    $clean = [Environment]::ExpandEnvironmentVariables($PathValue.Trim().Trim('"'))
    if (-not $clean) { return "" }
    try { $clean = [System.IO.Path]::GetFullPath($clean) } catch {}
    $clean = $clean.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $clean.ToUpperInvariant()
}

function Test-PryxSafePurgePath([string]$PathValue) {
    $pathKey = ConvertTo-PryxPathKey $PathValue
    if (-not $pathKey) { return $false }

    try {
        $fullPath = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($PathValue.Trim().Trim('"')))
        $rootKey = ConvertTo-PryxPathKey ([System.IO.Path]::GetPathRoot($fullPath))
        $leafName = [System.IO.Path]::GetFileName($fullPath.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ))
    } catch {
        return $false
    }

    if ($pathKey -eq $rootKey -or $leafName -notmatch '(?i)^\.?pryx(?:[-_ ].*)?$') {
        return $false
    }

    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    foreach ($protectedPath in @(
        $env:USERPROFILE,
        $env:HOME,
        $env:LOCALAPPDATA,
        $env:APPDATA,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    )) {
        $protectedKey = ConvertTo-PryxPathKey $protectedPath
        if (-not $protectedKey) { continue }
        if ($pathKey -eq $protectedKey -or $protectedKey.StartsWith($pathKey + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    return $true
}

function Test-PryxManagedExecutablePath([string]$ExecutablePath, [string]$LauncherPath, [string]$BuildsDir) {
    $executableKey = ConvertTo-PryxPathKey $ExecutablePath
    $launcherKey = ConvertTo-PryxPathKey $LauncherPath
    $buildsKey = ConvertTo-PryxPathKey $BuildsDir
    if (-not $executableKey) { return $false }
    if ($launcherKey -and $executableKey -eq $launcherKey) { return $true }

    # A live upgrade may rename the loaded stable launcher before replacing it.
    # Treat only that tightly-scoped backup pattern in the launcher directory as
    # managed so uninstall can stop and remove it without touching other tools.
    $launcherDirKey = ConvertTo-PryxPathKey (Split-Path -Parent $LauncherPath)
    $executableDirKey = ConvertTo-PryxPathKey (Split-Path -Parent $ExecutablePath)
    $executableName = Split-Path -Leaf $ExecutablePath
    if ($launcherDirKey -and $executableDirKey -eq $launcherDirKey -and $executableName -like '.pryx-launcher-old-*.exe') {
        return $true
    }

    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    return [bool]($buildsKey -and $executableKey.StartsWith($buildsKey + $separator, [System.StringComparison]::OrdinalIgnoreCase))
}

function Split-PryxPathList([string]$PathValue) {
    if (-not $PathValue) { return @() }
    $entries = @()
    foreach ($entry in ($PathValue -split ';')) {
        $clean = $entry.Trim().Trim('"')
        if ($clean) { $entries += $clean }
    }
    return $entries
}

function Join-PryxPathList([string[]]$Entries) {
    if (-not $Entries -or $Entries.Count -eq 0) { return "" }
    return ($Entries -join ';')
}

function Get-PryxManagedPathKeys([string]$InstallDir) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in @($InstallDir, (Get-DefaultPryxInstallDir))) {
        $key = ConvertTo-PryxPathKey $candidate
        if ($key) { [void]$keys.Add($key) }
    }
    return $keys
}

function Resolve-PryxPathRemoval {
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [AllowNull()][string]$CurrentPath
    )

    $managedKeys = Get-PryxManagedPathKeys -InstallDir $InstallDir
    $nextEntries = @()
    $removedManaged = 0

    foreach ($entry in (Split-PryxPathList $CurrentPath)) {
        $key = ConvertTo-PryxPathKey $entry
        if (-not $key) { continue }
        if ($managedKeys.Contains($key)) {
            $removedManaged += 1
            continue
        }
        $nextEntries += $entry
    }

    $nextPath = Join-PryxPathList $nextEntries
    return [pscustomobject]@{
        Path = $nextPath
        Changed = ($nextPath -ne ([string]$CurrentPath))
        RemovedManagedEntries = $removedManaged
        InstallDir = $InstallDir
    }
}

function Send-PryxEnvironmentChangedBroadcast {
    if ($env:PRYX_DISABLE_ENV_BROADCAST -eq "1") { return $false }
    if (-not ("Pryx.EnvironmentBroadcast" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Pryx {
    public static class EnvironmentBroadcast {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            UInt32 Msg,
            UIntPtr wParam,
            string lParam,
            UInt32 fuFlags,
            UInt32 uTimeout,
            out UIntPtr lpdwResult);
    }
}
"@
    }
    $result = [UIntPtr]::Zero
    [Pryx.EnvironmentBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref]$result) | Out-Null
    return $true
}

function Remove-PryxUserPath {
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [AllowNull()][string]$CurrentPath,
        [scriptblock]$SetUserPathAction,
        [scriptblock]$BroadcastAction,
        [bool]$Broadcast = $true
    )

    if (-not $PSBoundParameters.ContainsKey('CurrentPath')) {
        $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    }

    $update = Resolve-PryxPathRemoval -InstallDir $InstallDir -CurrentPath $CurrentPath
    $broadcasted = $false
    if ($update.Changed) {
        if ($SetUserPathAction) {
            & $SetUserPathAction $update.Path
        } else {
            [Environment]::SetEnvironmentVariable("Path", $update.Path, "User")
        }

        if ($Broadcast) {
            if ($BroadcastAction) { & $BroadcastAction | Out-Null } else { Send-PryxEnvironmentChangedBroadcast | Out-Null }
            $broadcasted = $true
        }
    }
    $update | Add-Member -NotePropertyName Broadcasted -NotePropertyValue $broadcasted
    return $update
}


function Invoke-PryxUninstall {
    param(
        [string]$InstallDir,
        [switch]$Purge,
        [switch]$DryRun,
        [switch]$Yes
    )

if (-not $InstallDir) { $InstallDir = Get-DefaultPryxInstallDir }

$localPryxRoot = Join-Path (Get-PryxLocalAppDataDir) "pryx"
$launcherPath = Join-Path $InstallDir "pryx.exe"
$buildsDir = Join-Path $localPryxRoot "builds"
$userDataDir = if ($env:PRYX_HOME) {
    $env:PRYX_HOME
} elseif ($env:USERPROFILE) {
    Join-Path $env:USERPROFILE ".pryx"
} else {
    Join-Path ([Environment]::GetFolderPath("UserProfile")) ".pryx"
}
$startupShortcutPath = Get-PryxStartupShortcutPath
$hotkeyArtifactPaths = @(Get-PryxHotkeyArtifactPaths -UserDataDir $userDataDir)
$launcherBackupPaths = if (Test-Path -LiteralPath $InstallDir) {
    @(Get-ChildItem -LiteralPath $InstallDir -Filter '.pryx-launcher-old-*.exe' -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName })
} else {
    @()
}
if ($Purge -and -not (Test-PryxSafePurgePath $userDataDir)) {
    Write-Err "Refusing to purge unsafe PRYX_HOME path '$userDataDir'. Use a dedicated .pryx or pryx-* directory."
}

$targets = @()
if (Test-Path -LiteralPath $launcherPath) { $targets += "$launcherPath (launcher)" }
foreach ($path in $launcherBackupPaths) { $targets += "$path (previous live-upgrade launcher)" }
if (Test-Path -LiteralPath $buildsDir) { $targets += "$buildsDir (installed binaries)" }
if (Test-Path -LiteralPath $startupShortcutPath) { $targets += "$startupShortcutPath (launch-hotkey startup shortcut)" }
foreach ($path in $hotkeyArtifactPaths) {
    if (Test-Path -LiteralPath $path) { $targets += "$path (launch-hotkey artifact)" }
}
if ($Purge -and (Test-Path -LiteralPath $userDataDir)) { $targets += "$userDataDir (user data)" }

$userPathPreview = Resolve-PryxPathRemoval -InstallDir $InstallDir -CurrentPath ([Environment]::GetEnvironmentVariable("Path", "User"))
if ($userPathPreview.RemovedManagedEntries -gt 0) {
    $targets += "$InstallDir (user PATH entry)"
}

if ($targets.Count -eq 0) {
    Write-Info "Nothing to uninstall: no pryx installation found."
    return 0
}

Write-Info "The following will be removed:"
foreach ($target in $targets) { Write-Host "  - $target" }
if (-not $Purge) {
    Write-Warn "User data in $userDataDir is kept. Run with -Purge for a full wipe."
}

if ($DryRun) {
    Write-Info "Dry run: nothing was deleted."
    return 0
}

if (-not $Yes) {
    $reply = Read-Host "Proceed? [y/N]"
    if ($reply -notin @("y", "Y", "yes", "YES")) {
        Write-Info "Aborted."
        return 1
    }
}

try {
    $managedProcessIds = @(Get-CimInstance Win32_Process -Filter "Name = 'pryx.exe'" -ErrorAction SilentlyContinue |
        Where-Object { Test-PryxManagedExecutablePath -ExecutablePath $_.ExecutablePath -LauncherPath $launcherPath -BuildsDir $buildsDir } |
        ForEach-Object { $_.ProcessId })
    foreach ($processId in $managedProcessIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        if ($process) {
            try { [void]$process.WaitForExit(10000) } catch {}
        }
    }
} catch {}

if (Test-Path -LiteralPath $startupShortcutPath) {
    Remove-Item -LiteralPath $startupShortcutPath -Force
    Write-Info "Removed $startupShortcutPath"
}

foreach ($path in $hotkeyArtifactPaths) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Info "Removed $path"
    }
}
if (-not $Purge) {
    $hotkeyDir = Join-Path $userDataDir "hotkey"
    if (Test-Path -LiteralPath $hotkeyDir) {
        Remove-Item -LiteralPath $hotkeyDir -Force -ErrorAction SilentlyContinue
    }
    Clear-PryxHotkeySetupState -UserDataDir $userDataDir
}

if (Test-Path -LiteralPath $launcherPath) {
    Remove-Item -LiteralPath $launcherPath -Force
    Write-Info "Removed $launcherPath"
}

foreach ($path in $launcherBackupPaths) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Info "Removed $path"
    }
}

if (Test-Path -LiteralPath $InstallDir) {
    try { Remove-Item -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue } catch {}
}

if ($Purge) {
    foreach ($path in @($localPryxRoot, $userDataDir)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-Info "Removed $path"
        }
    }
} elseif (Test-Path -LiteralPath $buildsDir) {
    Remove-Item -LiteralPath $buildsDir -Recurse -Force
    Write-Info "Removed $buildsDir"
}

$pathUpdate = Remove-PryxUserPath -InstallDir $InstallDir
if ($pathUpdate.Changed) {
    Write-Info "Removed $($pathUpdate.RemovedManagedEntries) pryx entr$(if ($pathUpdate.RemovedManagedEntries -eq 1) { 'y' } else { 'ies' }) from user PATH"
}

Write-Info "pryx uninstalled."
Write-Info "Reinstall with: irm https://pryx.sh/install.ps1 | iex"


    return 0
}

if ($env:PRYX_UNINSTALL_PS1_IMPORT_ONLY -ne "1") {
    $exitCode = Invoke-PryxUninstall -InstallDir $InstallDir -Purge:$Purge -DryRun:$DryRun -Yes:$Yes
    if ($null -ne $exitCode -and [int]$exitCode -ne 0) {
        if ($MyInvocation.MyCommand.Path) { exit ([int]$exitCode) }
        $global:LASTEXITCODE = [int]$exitCode
    }
}
