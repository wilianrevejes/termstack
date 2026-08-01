# setup-windows.ps1 -- the Windows setup for termstack (the WezTerm layer).
#
#   .\scripts\setup-windows.ps1            diagnose, ask, install, verify
#   .\scripts\setup-windows.ps1 -DryRun    diagnose only; change nothing
#   .\scripts\setup-windows.ps1 -Yes       never ask anything (automation)
#   .\scripts\setup-windows.ps1 -Help      this help
#
# This sets up the WINDOWS half only: WezTerm + the Nerd Font (through
# bootstrap-windows.ps1) and machine.lua. The CLI layer -- tmux, zellij, neovim,
# zsh -- is a SEPARATE setup you run inside your WSL distro (see the pointer it
# prints at the end). The two are kept apart on purpose, mirroring the split on
# disk: WezTerm renders on Windows, the tools live in WSL.
#
# UI symbols are built from code points so the source stays pure ASCII: Windows
# PowerShell 5.1 (the "Run with PowerShell" default) misreads a non-ASCII,
# BOM-less .ps1 at parse time. They render once the console output encoding is
# UTF-8, set below.

param(
    [switch] $DryRun,
    [switch] $Yes,
    [switch] $Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# $IsWindows only exists on PowerShell 6+. On Windows PowerShell 5.1 the
# variable does not exist and, under StrictMode, referencing it throws. Since
# 5.1 only runs on Windows, the check only makes sense on 6+ -- the -ge 6
# short-circuit keeps 5.1 from ever evaluating $IsWindows.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "This script must be run on Windows."
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$repoDir = Split-Path -Parent $PSScriptRoot

# ---- Appearance ----------------------------------------------------------
# A minimal echo of the ui_* vocabulary in scripts/_common.sh (which cannot be
# sourced from PowerShell): the same BMP symbols, the same 256-color catppuccin
# palette, so the Windows setup reads like the same program as setup.sh.

$SymOk    = [char]0x2714  # heavy check mark
$SymWarn  = [char]0x25B2  # up-pointing triangle
$SymBad   = [char]0x2716  # heavy multiplication x
$SymSkip  = [char]0x00B7  # middle dot
$SymArrow = [char]0x2192  # rightwards arrow
$SymFull  = [char]0x25CF  # black circle
$SymEmpty = [char]0x25CB  # white circle
$SymMid   = [char]0x00B7  # middle dot (banner subtitle separator)
$BoxTL = [char]0x256D; $BoxTR = [char]0x256E; $BoxBL = [char]0x2570; $BoxBR = [char]0x256F
$BoxH  = [char]0x2500; $BoxV  = [char]0x2502

$e = [char]27
if (-not [Console]::IsOutputRedirected) {
    $UiB  = "$e[1m"; $UiDim = "$e[2m"; $UiR = "$e[0m"
    $UiAz = "$e[38;5;111m"; $UiVd = "$e[38;5;114m"
    $UiAm = "$e[38;5;180m"; $UiVm = "$e[38;5;210m"
} else {
    $UiB = ''; $UiDim = ''; $UiR = ''; $UiAz = ''; $UiVd = ''; $UiAm = ''; $UiVm = ''
}

$script:UiStep  = 0
$script:UiSteps = 3

# ---- Presentation helpers ------------------------------------------------

function Show-Usage {
    Write-Host "setup-windows.ps1 - the Windows setup for termstack (the WezTerm layer)."
    Write-Host ""
    Write-Host "  .\scripts\setup-windows.ps1            diagnose, ask, install, verify"
    Write-Host "  .\scripts\setup-windows.ps1 -DryRun    diagnose only; change nothing"
    Write-Host "  .\scripts\setup-windows.ps1 -Yes       never ask anything (automation)"
    Write-Host "  .\scripts\setup-windows.ps1 -Help      this help"
    Write-Host ""
    Write-Host "The CLI layer is a separate setup, run inside WSL:  bash scripts/setup.sh"
}

function Banner {
    param([string] $Title, [string] $Sub)
    $w = 58
    $rule  = ([string] $BoxH) * $w
    $inner = $w - 4
    $padT = $Title + (' ' * [Math]::Max(0, $inner - $Title.Length))
    $padS = $Sub   + (' ' * [Math]::Max(0, $inner - $Sub.Length))
    Write-Host ""
    Write-Host ("  {0}{1}{2}{3}{4}" -f $UiAz, $BoxTL, $rule, $BoxTR, $UiR)
    Write-Host ("  {0}{1}{2}  {3}{4}{5}  {6}{7}{8}" -f $UiAz, $BoxV, $UiR, $UiB, $padT, $UiR, $UiAz, $BoxV, $UiR)
    Write-Host ("  {0}{1}{2}  {3}{4}{5}  {6}{7}{8}" -f $UiAz, $BoxV, $UiR, $UiDim, $padS, $UiR, $UiAz, $BoxV, $UiR)
    Write-Host ("  {0}{1}{2}{3}{4}" -f $UiAz, $BoxBL, $rule, $BoxBR, $UiR)
}

function Step {
    param([string] $Title, [string] $Desc)
    $script:UiStep++
    $dots = ''
    for ($i = 1; $i -le $script:UiSteps; $i++) {
        if ($i -le $script:UiStep) { $dots += $SymFull } else { $dots += $SymEmpty }
    }
    Write-Host ""
    Write-Host ("{0}{1}{2}  {3}{4}{5}/{6}  {7}{8}" -f $UiAz, $dots, $UiR, $UiB, $UiAz, $script:UiStep, $script:UiSteps, $Title, $UiR)
    if ($Desc) { Write-Host ("  {0}{1}{2}" -f $UiDim, $Desc, $UiR) }
}

function Ok    { param([string] $m) Write-Host ("    {0}{1}{2} {3}" -f $UiVd, $SymOk, $UiR, $m) }
function Warn  { param([string] $m) Write-Host ("    {0}{1}{2} {3}" -f $UiAm, $SymWarn, $UiR, $m) }
function Bad   { param([string] $m) Write-Host ("    {0}{1}{2} {3}" -f $UiVm, $SymBad, $UiR, $m) }
function Skip  { param([string] $m) Write-Host ("    {0}{1}{2} {3}{4}{5}" -f $UiDim, $SymSkip, $UiR, $UiDim, $m, $UiR) }
function Note  { param([string] $m) Write-Host ("      {0}{1}{2}" -f $UiDim, $m, $UiR) }
function Run   { param([string] $m) Write-Host ("    {0}{1}{2} {3}" -f $UiAz, $SymArrow, $UiR, $m) }
function Group { param([string] $m) Write-Host ""; Write-Host ("  {0}{1}{2}" -f $UiB, $m, $UiR) }

# The step's verdict: group indentation, a leading blank, a bold line.
function Res {
    param([string] $Color, [string] $Symbol, [string] $m)
    Write-Host ""
    Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $Color, $Symbol, $UiR, $UiB, $m, $UiR)
}
function ResOk   { param([string] $m) Res $UiVd $SymOk   $m }
function ResWarn { param([string] $m) Res $UiAm $SymWarn $m }
function ResBad  { param([string] $m) Res $UiVm $SymBad  $m }

# y/N question. Returns $true with -Yes; $false when input is redirected (no one
# to answer) -- mirrors ui_ask in _common.sh. "s" is accepted alongside "y".
function Ask {
    param([string] $q)
    if ($Yes) { return $true }
    if ([Console]::IsInputRedirected) { return $false }
    Write-Host ""
    Write-Host ("  {0}?{1} {2} {3}[y/N]{4} " -f $UiAz, $UiR, $q, $UiDim, $UiR) -NoNewline
    $answer = Read-Host
    return ($answer -match '^[yYsS]')
}

function Get-Upstream {
    try { $u = & git -C $repoDir remote get-url origin 2>$null } catch { return $null }
    if ($u) { return "$u".Trim() }
    return $null
}

# The CLI layer is a SEPARATE setup, run inside WSL. This only points the way;
# it never reaches into the distro (that is setup.sh's job, run there).
function Show-WslNext {
    param([bool] $HasWsl)
    Group "next: the CLI layer, inside WSL - a separate setup"
    if (-not $HasWsl) {
        Note "install WSL first:  wsl --install -d Ubuntu   (then reopen and continue)"
    }
    $src = Get-Upstream
    if (-not $src) { $src = "<the termstack repo url>" }
    Note "open your WSL distro, then, on the distro filesystem (NOT /mnt/c):"
    Note ("  git clone {0} ~/.config/wezterm" -f $src)
    Note "  cd ~/.config/wezterm && bash scripts/setup.sh"
    Note "It detects WSL and skips WezTerm - rendering here is done by Windows WezTerm."
}

# ---- Body ----------------------------------------------------------------

if ($Help) { Show-Usage; exit 0 }

if ($args.Count -gt 0) {
    [Console]::Error.WriteLine("Unknown argument: $($args -join ' ')")
    Show-Usage
    exit 64
}

Banner "termstack" ("Windows setup  {0}  the WezTerm layer" -f $SymMid)

# ---- 1. Diagnose ---------------------------------------------------------
Step "diagnose" "the Windows side - what is already here?"

Note ("PowerShell {0}" -f $PSVersionTable.PSVersion)

$hasWinget = [bool] (Get-Command winget.exe -ErrorAction SilentlyContinue)
if ($hasWinget) { Ok "winget present" } else { Warn "winget missing - needed to install WezTerm and the font" }

$hasWezterm = [bool] (Get-Command wezterm.exe -ErrorAction SilentlyContinue)
if ($hasWezterm) { Ok "wezterm already installed" } else { Skip "wezterm not installed yet" }

$hasWsl = [bool] (Get-Command wsl.exe -ErrorAction SilentlyContinue)
if ($hasWsl) { Ok "wsl present (the CLI layer is a separate setup - see the end)" } else { Warn "wsl not found - you will want it for the CLI layer" }

$configHome = Join-Path $HOME ".config\wezterm"
if ($repoDir -eq $configHome) {
    Ok "repo is at ~\.config\wezterm - wezterm finds it with no extra config"
} elseif ($env:WEZTERM_CONFIG_FILE) {
    Ok "WEZTERM_CONFIG_FILE is set"
} else {
    Warn "repo is not at ~\.config\wezterm and WEZTERM_CONFIG_FILE is unset"
}

if ($DryRun) {
    Note "dry run - nothing will be installed or changed"
    Note "would install:  wez.wezterm, DEVCOM.JetBrainsMonoNerdFont"
    Note "would seed machine.lua, and point you at the WSL setup"
    ResOk "diagnose only (dry run)"
    exit 0
}

# ---- 2. Install (the Windows layer) --------------------------------------
# With no terminal and no -Yes, nobody can confirm. Do not install because the
# output was piped somewhere.
if (-not $Yes -and [Console]::IsInputRedirected) {
    ResBad "no terminal to confirm on - re-run in a real console, or pass -Yes"
    exit 0
}

Step "install" "WezTerm and the Nerd Font, via winget"

$bootstrap = Join-Path $PSScriptRoot "bootstrap-windows.ps1"
try {
    $env:TERMSTACK_FROM_SETUP = '1'
    & $bootstrap
} catch {
    ResBad "the Windows install did not finish"
    Note $_.Exception.Message
    Note "install WezTerm + JetBrainsMono Nerd Font by hand, then re-run"
    exit 1
} finally {
    Remove-Item Env:\TERMSTACK_FROM_SETUP -ErrorAction SilentlyContinue
}

if ($repoDir -eq $configHome) {
    Skip "wezterm config already at ~\.config\wezterm"
} elseif ($env:WEZTERM_CONFIG_FILE) {
    Skip "WEZTERM_CONFIG_FILE already set"
} elseif (Ask "point WEZTERM_CONFIG_FILE at this repo so WezTerm loads it?") {
    setx WEZTERM_CONFIG_FILE "$repoDir\wezterm.lua" | Out-Null
    Ok "set WEZTERM_CONFIG_FILE (takes effect in new terminals)"
} else {
    Note ("later:  setx WEZTERM_CONFIG_FILE `"{0}\wezterm.lua`"" -f $repoDir)
}

ResOk "Windows layer installed"

# ---- 3. Verify (the Windows/WezTerm layer) -------------------------------
Step "verify" "does WezTerm load the config?"

$weztermBin = Get-Command wezterm.exe -ErrorAction SilentlyContinue
if ($weztermBin) {
    $cfg  = Join-Path $repoDir "wezterm.lua"
    $keys = & wezterm.exe --config-file $cfg show-keys 2>$null
    if ((@($keys) -join "`n") -match '(?m)^Leader:') {
        ResOk "the WezTerm layer is ready"
    } else {
        ResBad "wezterm did not load the config"
        Note ("try:  wezterm --config-file `"{0}`" show-keys" -f $cfg)
        Show-WslNext $hasWsl
        exit 1
    }
} else {
    ResWarn "wezterm not on PATH yet - open a new terminal to pick up the winget shim"
}

Show-WslNext $hasWsl
exit 0
