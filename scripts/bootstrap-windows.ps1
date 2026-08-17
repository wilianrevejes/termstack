# Installs WezTerm + font on Windows and seeds machine.lua. Idempotent.
#
# The platform installer for the Windows side: setup-windows.ps1 calls it (with
# TERMSTACK_FROM_SETUP set, which suppresses the standalone epilogue below), or
# you can run it on its own.

param([switch] $DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# $IsWindows only exists on PowerShell 6+. On Windows PowerShell 5.1 -- which
# is still the default for "Run with PowerShell" -- the variable does not
# exist and, under StrictMode, referencing it throws an error. Since 5.1 only
# runs on Windows, the check only makes sense on 6+.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "This script must be run on Windows."
}

$repoDir = Split-Path -Parent $PSScriptRoot

# For $TermstackPackages: the list of what the native stack installs lives in
# one place, so update-windows.ps1 upgrades exactly what this installs. Two
# copies is how a tool gets installed on new machines and never upgraded on the
# old ones.
. (Join-Path $PSScriptRoot '_common-windows.ps1')

if ($DryRun) {
    Write-Host "==> dry run: would install WezTerm (wez.wezterm) and JetBrainsMono Nerd Font"
    Write-Host "==> dry run: would seed machine.lua from machine.example.lua if missing"
    return
}

if (-not (Get-Command "winget.exe" -ErrorAction SilentlyContinue)) {
    throw @"
WinGet was not found.

Install it manually:
  WezTerm: https://wezterm.org/install/windows.html
  Font:    https://www.nerdfonts.com/font-downloads (JetBrainsMono)
"@
}

function Install-IfMissing {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Name
    )

    winget list --id $Id --exact --accept-source-agreements *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "==> $Name already installed"
        return
    }

    Write-Host "==> Installing $Name"

    winget install `
        --id $Id `
        --exact `
        --accept-package-agreements `
        --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install ${Name}: winget exited with $LASTEXITCODE."
    }
}

# WezTerm and the font, then the native CLI stack: Zellij (native on Windows
# since v0.44), Neovim, and the tools LazyVim/the shell reach for. tmux and zsh
# are Unix-only and are left to the separate Linux setup (scripts/setup.sh, run
# inside WSL).
foreach ($p in $TermstackPackages) {
    Install-IfMissing -Id $p.Id -Name $p.Name
}

$machine = Join-Path $repoDir "machine.lua"

if (Test-Path $machine) {
    Write-Host "==> machine.lua already exists, kept"
}
else {
    Copy-Item (Join-Path $repoDir "machine.example.lua") $machine
    Write-Host "==> machine.lua created from machine.example.lua"
}

# Standalone epilogue: the manual next-steps. setup-windows.ps1 owns the WSL
# orchestration and the config-path guidance, so it sets TERMSTACK_FROM_SETUP
# to skip this.
if (-not $env:TERMSTACK_FROM_SETUP) {
    Write-Host ""
    Write-Host "Done."
    Write-Host ""
    Write-Host "tmux does not run on native Windows. To get tmux configured, open"
    Write-Host "your WSL distro and run inside it:"
    Write-Host "  bash scripts/setup.sh"
    Write-Host "It detects WSL and skips the WezTerm install."
    Write-Host ""
    Write-Host "Prefer to clone the repository a second time inside WSL, on the"
    Write-Host "distro file system. Running it from /mnt/c works, but it gets"
    Write-Host "slow and the execute bit does not survive NTFS."

    # I do not point to `wezterm show-keys`: it exits with 0 even with a broken
    # config, silently falling back to the default. check.sh knows that.
    Write-Host "Check everything with (Git Bash, which came along with git):"
    Write-Host "  bash `"$repoDir/scripts/check.sh`""
}
