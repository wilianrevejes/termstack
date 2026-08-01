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

# ---- Appearance ----------------------------------------------------------

$SymOk    = [char]0x2714
$SymWarn  = [char]0x25B2
$SymBad   = [char]0x2716
$SymSkip  = [char]0x00B7
$SymArrow = [char]0x2192
$SymFull  = [char]0x25CF
$SymEmpty = [char]0x25CB
$SymMid   = [char]0x00B7
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

function Res {
    param([string] $Color, [string] $Symbol, [string] $m)
    Write-Host ""
    Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $Color, $Symbol, $UiR, $UiB, $m, $UiR)
}
function ResOk   { param([string] $m) Res $UiVd $SymOk   $m }
function ResWarn { param([string] $m) Res $UiAm $SymWarn $m }
function ResBad  { param([string] $m) Res $UiVm $SymBad  $m }

function Ask {
    param([string] $q)
    if ($Yes) { return $true }
    if ([Console]::IsInputRedirected) { return $false }
    Write-Host ""
    Write-Host ("  {0}?{1} {2} {3}[y/N]{4} " -f $UiAz, $UiR, $q, $UiDim, $UiR) -NoNewline
    $answer = Read-Host
    return ($answer -match '^[yYsS]')
}

# ---- Config wiring helpers -----------------------------------------------

# Absolute pwsh path (pwsh 7 first, then Windows PowerShell) with forward
# slashes -- accepted by both zellij's default_shell and Windows, and free of
# KDL backslash-escaping.
function Get-PwshPath {
    $c = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $c) { $c = Get-Command powershell.exe -ErrorAction SilentlyContinue }
    if ($c) { return ($c.Source -replace '\\', '/') }
    return 'pwsh.exe'
}

# The zellij config derived from the shared zellij/config.kdl. Pure function
# (no writes) so a test can diff it. Two edits the shared file cannot carry:
#   1. default_shell = pwsh (the shared config leaves it as $SHELL for Unix).
#   2. the cheat-sheet keybind shells out to bash at a Unix path; point it at
#      the repo's cheatsheet.sh through Git Bash instead.
function Get-ZellijConfigText {
    param([string] $RepoDir)
    $text = [IO.File]::ReadAllText((Join-Path $RepoDir 'zellij\config.kdl'))

    $header = "// GENERATED by setup-windows.ps1 from zellij/config.kdl -- edit the source, not this.`n" +
              "// default_shell is injected here so the shared config stays pwsh-free on macOS/WSL.`n" +
              "default_shell `"$(Get-PwshPath)`"`n`n"

    # Git-Bash (MSYS) form of the repo's cheatsheet.sh: /c/Users/.../cheatsheet.sh
    $drive = $RepoDir.Substring(0, 1).ToLower()
    $rest  = ($RepoDir.Substring(2) -replace '\\', '/')
    $sheet = "/$drive$rest/scripts/cheatsheet.sh"

    $oldRun = 'Run "bash" "-c" "cd -P \"$HOME/.config/zellij\" && bash ../scripts/cheatsheet.sh; read -rsn1"'
    $newRun = "Run `"bash`" `"-c`" `"bash '$sheet'; read -rsn1`""
    $text = $text.Replace($oldRun, $newRun)

    return $header + $text
}

function Write-ZellijConfig {
    param([string] $RepoDir)
    $dir = Join-Path $env:APPDATA 'Zellij\config'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $dir 'config.kdl'), (Get-ZellijConfigText $RepoDir), $enc)
    $layoutsSrc = Join-Path $RepoDir 'zellij\layouts'
    if (Test-Path $layoutsSrc) {
        $layoutsDst = Join-Path $dir 'layouts'
        if (-not (Test-Path $layoutsDst)) { New-Item -ItemType Directory -Path $layoutsDst -Force | Out-Null }
        Copy-Item (Join-Path $layoutsSrc '*') $layoutsDst -Recurse -Force
    }
    Ok "zellij config generated (default_shell = pwsh)"
}

# A directory junction (no elevation needed), refusing to clobber a real dir --
# the same promise as link_config on Unix.
function New-ConfigJunction {
    param([string] $Link, [string] $Target, [string] $Label)
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.LinkType) { Skip "$Label already linked" ; return }
        Warn "$Link exists and is not a link - not overwriting"
        Note "move it aside and re-run to link it"
        return
    }
    $parent = Split-Path -Parent $Link
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Ok "$Label linked to the repo"
}

# Dot-source pwsh/profile.ps1 from the user's $PROFILE via a marked block that a
# re-run refreshes (strip + rewrite; only the delimited block is touched).
function Install-PwshProfile {
    param([string] $RepoDir)
    $profilePath = $PROFILE.CurrentUserAllHosts
    $parent = Split-Path -Parent $profilePath
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $text = ''
    if (Test-Path $profilePath) { $text = [IO.File]::ReadAllText($profilePath) }
    # strip an existing termstack block (idempotent refresh)
    $text = [regex]::Replace($text, '(?ms)\r?\n?# >>> termstack >>>.*?# <<< termstack <<<\r?\n?', "`n")
    $block = "`n# >>> termstack >>>`n. `"$RepoDir\pwsh\profile.ps1`"`n# <<< termstack <<<`n"
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($profilePath, ($text.TrimEnd() + "`n" + $block), $enc)
    Ok "pwsh profile wired ($([IO.Path]::GetFileName($profilePath)))"
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

New-ConfigJunction (Join-Path $env:LOCALAPPDATA 'nvim') (Join-Path $repoDir 'nvim') 'neovim config'
Write-ZellijConfig $repoDir
Install-PwshProfile $repoDir
setx EDITOR nvim  | Out-Null
setx VISUAL nvim  | Out-Null
Ok "EDITOR/VISUAL = nvim"

ResOk "configs wired"

# ---- 4. Neovim plugins ---------------------------------------------------
Step "plugins" "installing the LazyVim plugins (first run compiles treesitter)"

$nvim = Get-Command nvim -ErrorAction SilentlyContinue
if ($nvim) {
    Run "nvim --headless +Lazy! install"
    & $nvim.Source --headless "+Lazy! install" +qa 2>$null
    & $nvim.Source --headless "+Lazy! restore" +qa 2>$null
    ResOk "plugins installed"
} else {
    ResWarn "nvim not on PATH yet - open a new terminal, then run:  nvim +Lazy"
}

# ---- 5. Verify -----------------------------------------------------------
Step "verify" "does the stack load?"

$verifyOk = $true

$weztermBin = Get-Command wezterm.exe -ErrorAction SilentlyContinue
if ($weztermBin) {
    $keys = & wezterm.exe --config-file (Join-Path $repoDir 'wezterm.lua') show-keys 2>$null
    if ((@($keys) -join "`n") -match '(?m)^Leader:') { Ok "wezterm loads the config" }
    else { Bad "wezterm did not load the config"; $verifyOk = $false }
} else { Skip "wezterm not on PATH yet - open a new terminal" }

$zellijBin = Get-Command zellij -ErrorAction SilentlyContinue
if ($zellijBin) {
    $env:ZELLIJ_CONFIG_DIR = Join-Path $env:APPDATA 'Zellij\config'
    & $zellijBin.Source setup --check *> $null
    if ($LASTEXITCODE -eq 0) { Ok "zellij config is valid" } else { Bad "zellij config check failed"; $verifyOk = $false }
    Remove-Item Env:\ZELLIJ_CONFIG_DIR -ErrorAction SilentlyContinue
} else { Skip "zellij not on PATH yet" }

foreach ($t in @('nvim', 'rg', 'fd', 'lazygit')) {
    if (Get-Command $t -ErrorAction SilentlyContinue) { Ok "$t on PATH" } else { Warn "$t not on PATH - open a new terminal" }
}

if ($verifyOk) {
    ResOk "termstack is ready"
    Group "next steps"
    Note "1  open a new WezTerm window (it starts in pwsh, with the aliases loaded)"
    Note "2  zj            start Zellij"
    Note "3  nvim          LazyVim finishes on first use"
    Note "for the zsh/tmux layer: run  bash scripts/setup.sh  inside a WSL distro"
    exit 0
} else {
    ResWarn "some checks failed - see above"
    exit 1
}
