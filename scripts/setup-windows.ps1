# setup-windows.ps1 -- the NATIVE Windows setup for termstack.
#
#   .\scripts\setup-windows.ps1            diagnose, ask, install, verify
#   .\scripts\setup-windows.ps1 -DryRun    diagnose only; change nothing
#   .\scripts\setup-windows.ps1 -Yes       never ask anything (automation)
#   .\scripts\setup-windows.ps1 -Help      this help
#
# Installs and wires the whole stack that runs NATIVELY on Windows: WezTerm +
# the Nerd Font, Zellij (native since v0.44), Neovim/LazyVim, and the CLI tools,
# all via winget, with pwsh as the shell. tmux and zsh are Unix-only -- for that
# layer, run the separate Linux setup (bash scripts/setup.sh) inside a WSL
# distro. The bootstrap script is called by this one, not directly.
#
# UI symbols are built from code points so the source stays pure ASCII: Windows
# PowerShell 5.1 misreads a non-ASCII, BOM-less .ps1 at parse time. They render
# once the console output encoding is UTF-8, set below.

param(
    [switch] $DryRun,
    [switch] $Yes,
    [switch] $Help,
    [switch] $EmitZellijConfig   # internal: print the generated zellij config and exit (for tests)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "This script must be run on Windows."
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$repoDir = Split-Path -Parent $PSScriptRoot

# The presentation helpers, the config wiring, the winget package list and the
# stack check live in _common-windows.ps1, shared with update-windows.ps1.
# Dot-sourced, so they land in this script's scope.
. (Join-Path $PSScriptRoot '_common-windows.ps1')

$script:UiSteps = 5

# ---- Presentation helpers ------------------------------------------------

function Show-Usage {
    Write-Host "setup-windows.ps1 - the native Windows setup for termstack."
    Write-Host ""
    Write-Host "  .\scripts\setup-windows.ps1            diagnose, ask, install, verify"
    Write-Host "  .\scripts\setup-windows.ps1 -DryRun    diagnose only; change nothing"
    Write-Host "  .\scripts\setup-windows.ps1 -Yes       never ask anything (automation)"
    Write-Host "  .\scripts\setup-windows.ps1 -Help      this help"
    Write-Host ""
    Write-Host "The zsh/tmux layer is a separate setup, run inside WSL:  bash scripts/setup.sh"
}

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

# ---- Body ----------------------------------------------------------------

if ($EmitZellijConfig) { [Console]::Out.Write((Get-ZellijConfigText $repoDir)); exit 0 }

if ($Help) { Show-Usage; exit 0 }

if ($args.Count -gt 0) {
    [Console]::Error.WriteLine("Unknown argument: $($args -join ' ')")
    Show-Usage
    exit 64
}

Banner "termstack" ("WezTerm {0} Zellij {0} LazyVim {0} pwsh" -f $SymMid)

# ---- 1. Diagnose ---------------------------------------------------------
Step "diagnose" "the native Windows stack - what is already here?"

Note ("PowerShell {0}" -f $PSVersionTable.PSVersion)

$hasWinget  = [bool] (Get-Command winget.exe  -ErrorAction SilentlyContinue)
if ($hasWinget)  { Ok "winget present" } else { Warn "winget missing - needed to install the stack" }
foreach ($t in @('wezterm', 'nvim', 'zellij', 'git', 'rg', 'fd', 'node')) {
    if (Get-Command $t -ErrorAction SilentlyContinue) { Ok "$t installed" } else { Skip "$t not installed yet" }
}

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
    Note "would install:  WezTerm, the Nerd Font, Neovim, Zellij, git, ripgrep, fd,"
    Note "                lazygit, fzf, zoxide, bat, node, zig"
    Note "would wire:  nvim + zellij configs, the pwsh profile, EDITOR=nvim"
    ResOk "diagnose only (dry run)"
    exit 0
}

# ---- 2. Install ----------------------------------------------------------
if (-not $Yes -and [Console]::IsInputRedirected) {
    ResBad "no terminal to confirm on - re-run in a real console, or pass -Yes"
    exit 0
}

Step "install" "WezTerm, Neovim, Zellij and the CLI tools, via winget"

$bootstrap = Join-Path $PSScriptRoot "bootstrap-windows.ps1"
try {
    $env:TERMSTACK_FROM_SETUP = '1'
    & $bootstrap
} catch {
    ResBad "the install did not finish"
    Note $_.Exception.Message
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

ResOk "installed"

# ---- 3. Wire configs -----------------------------------------------------
Step "wire" "nvim + zellij configs, the pwsh profile"

New-ConfigJunction (Get-NvimConfigLink) (Join-Path $repoDir 'nvim') 'neovim config'
Write-ZellijConfig $repoDir
Install-PwshProfile $repoDir
setx EDITOR nvim  | Out-Null
setx VISUAL nvim  | Out-Null
Ok "EDITOR/VISUAL = nvim"

ResOk "configs wired"

# ---- 4. Neovim plugins ---------------------------------------------------
Step "plugins" "installing the LazyVim plugins (first run compiles treesitter)"

$nvim = Get-Command nvim -ErrorAction SilentlyContinue
Sync-NvimPlugins
if ($nvim) { ResOk "plugins installed" }
else { ResWarn "open a new terminal, then run:  nvim +Lazy" }

# ---- 5. Verify -----------------------------------------------------------
Step "verify" "does the stack load?"

# The same check update-windows.ps1 runs before deciding whether to roll back:
# one definition of "the stack is healthy", not two that drift.
$verifyOk = Test-TermstackStack $repoDir

if ($verifyOk) {
    ResOk "termstack is ready"
    Section "next steps"
    Note "1  open a new WezTerm window (it starts in pwsh, with the aliases loaded)"
    Note "2  zj            start Zellij"
    Note "3  nvim          LazyVim finishes on first use"
    Note "for the zsh/tmux layer: run  bash scripts/setup.sh  inside a WSL distro"
    exit 0
} else {
    ResWarn "some checks failed - see above"
    exit 1
}
