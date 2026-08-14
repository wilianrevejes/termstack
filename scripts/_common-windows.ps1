# _common-windows.ps1 -- what the native Windows scripts share.
#
# The counterpart of _common.sh for the Windows side: presentation helpers,
# config wiring, the winget package list, the snapshot/rollback machinery and
# the stack check. It is dot-sourced, never run on its own: the file only
# DEFINES things, so a test can source it and exercise one function in
# isolation, without a machine being touched.
#
# Pure ASCII on purpose -- the symbols are built from code points -- because
# Windows PowerShell 5.1 misreads a non-ASCII, BOM-less .ps1 at parse time.

# A native command that exits non-zero must not throw: this whole file is built
# on reading $LASTEXITCODE (git, winget, zellij all answer that way). PowerShell
# 7.3+ can turn those into terminating errors, and a future default flip would
# break every `2>$null` gate below.
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

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

# Dot-sourcing runs in the caller's scope, so these land in the calling
# script's scope -- each script sets its own $UiSteps after sourcing.
$script:UiStep  = 0
$script:UiSteps = 5

# ---- Presentation helpers ------------------------------------------------

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
function Section { param([string] $m) Write-Host ""; Write-Host ("  {0}{1}{2}" -f $UiB, $m, $UiR) }

function Res {
    param([string] $Color, [string] $Symbol, [string] $m)
    Write-Host ""
    Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $Color, $Symbol, $UiR, $UiB, $m, $UiR)
}
function ResOk   { param([string] $m) Res $UiVd $SymOk   $m }
function ResWarn { param([string] $m) Res $UiAm $SymWarn $m }
function ResBad  { param([string] $m) Res $UiVm $SymBad  $m }

# ---- Small utilities -----------------------------------------------------

# UTF-8 WITHOUT a BOM. Set-Content/Out-File on Windows PowerShell 5.1 default to
# UTF-16 or to a BOM, and both break the files written here: zellij's KDL parser
# and `. profile.ps1` choke on the BOM.
function Write-Utf8 {
    param([string] $Path, [string] $Text)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Text, $enc)
}

# Substring(0, 7) on a rev that is not a rev -- 'none', on a tree with no HEAD --
# throws, and $ErrorActionPreference = Stop would kill the update halfway
# through, which is the one thing this script exists to avoid.
function Get-ShortRev {
    param([string] $Rev)
    if ($Rev -and $Rev.Length -ge 7) { return $Rev.Substring(0, 7) }
    return $Rev
}

# Path comparison that survives a trailing slash, 8.3 shortening and the case
# difference between `C:\Users\...` and `C:\users\...`.
function Test-SamePath {
    param([string] $A, [string] $B)
    if (-not $A -or -not $B) { return $false }
    try {
        $a = [IO.Path]::GetFullPath($A).TrimEnd('\')
        $b = [IO.Path]::GetFullPath($B).TrimEnd('\')
    } catch { return $false }
    return $a -ieq $b
}

# Runs a native command with a deadline and returns its exit code, or 142 --
# the same number a SIGALRM gives on Unix, which is what check.sh reports.
#
# Never through a pipeline: killing a process that holds the write end of a pipe
# leaves the reader blocked (git's `git-remote-https` is the classic one). The
# output goes to files, and only the parent gets killed if the tree kill is not
# available.
function Invoke-Timed {
    param(
        [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [int] $Seconds = 20,
        [string] $StdOut,
        [string] $StdErr
    )

    if (-not $StdOut) { $StdOut = [IO.Path]::GetTempFileName() }
    if (-not $StdErr) { $StdErr = [IO.Path]::GetTempFileName() }

    # -ArgumentList joins with spaces and quotes nothing: a repo path with a
    # space would arrive as two arguments.
    $quoted = @()
    foreach ($a in $ArgumentList) {
        if ($a -match '\s' -and $a -notmatch '^"') { $quoted += """$a""" } else { $quoted += $a }
    }

    $p = Start-Process -FilePath $FilePath -ArgumentList $quoted -NoNewWindow -PassThru `
        -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr

    if (-not $p.WaitForExit($Seconds * 1000)) {
        # Kill($true) (the whole tree) is .NET Core only; 5.1 gets the parent.
        try { $p.Kill($true) } catch { try { $p.Kill() } catch { } }
        return 142
    }

    return $p.ExitCode
}

# ---- Config wiring -------------------------------------------------------

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

function Get-ZellijConfigDir {
    Join-Path $env:APPDATA 'Zellij\config'
}

function Write-ZellijConfig {
    param([string] $RepoDir)
    $dir = Get-ZellijConfigDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Utf8 (Join-Path $dir 'config.kdl') (Get-ZellijConfigText $RepoDir)
    $layoutsSrc = Join-Path $RepoDir 'zellij\layouts'
    if (Test-Path $layoutsSrc) {
        $layoutsDst = Join-Path $dir 'layouts'
        if (-not (Test-Path $layoutsDst)) { New-Item -ItemType Directory -Path $layoutsDst -Force | Out-Null }
        Copy-Item (Join-Path $layoutsSrc '*') $layoutsDst -Recurse -Force
    }
    Ok "zellij config generated (default_shell = pwsh)"
}

function Get-NvimConfigLink {
    Join-Path $env:LOCALAPPDATA 'nvim'
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

# Where a junction points. 5.1 hands back an array, 7 a string.
function Get-LinkTarget {
    param([string] $Path)
    if (-not (Test-Path $Path)) { return $null }
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if (-not $item -or -not $item.LinkType) { return $null }
    return @($item.Target)[0]
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
    Write-Utf8 $profilePath ($text.TrimEnd() + "`n" + $block)
    Ok "pwsh profile wired ($([IO.Path]::GetFileName($profilePath)))"
}

function Copy-MachineLua {
    param([string] $RepoDir)
    $machine = Join-Path $RepoDir 'machine.lua'
    if (Test-Path $machine) {
        Skip "machine.lua kept"
    } else {
        Copy-Item (Join-Path $RepoDir 'machine.example.lua') $machine
        Ok "machine.lua created from machine.example.lua"
    }
}

# Everything the native stack needs pointed at the repo. Offline-safe: no
# network, no winget -- exactly the part of the update that must run anyway.
function Set-TermstackWiring {
    param([string] $RepoDir)
    Copy-MachineLua $RepoDir
    New-ConfigJunction (Get-NvimConfigLink) (Join-Path $RepoDir 'nvim') 'neovim config'
    Write-ZellijConfig $RepoDir
    Install-PwshProfile $RepoDir
}

# ---- Packages ------------------------------------------------------------

# THE list, in one place: bootstrap installs from it, update upgrades from it.
# Two copies is how a tool gets installed on new machines and never upgraded on
# the old ones.
$TermstackPackages = @(
    @{ Id = 'wez.wezterm';                  Name = 'WezTerm' }
    @{ Id = 'DEVCOM.JetBrainsMonoNerdFont'; Name = 'JetBrainsMono Nerd Font' }
    @{ Id = 'Neovim.Neovim';                Name = 'Neovim' }
    @{ Id = 'Zellij.Zellij';                Name = 'Zellij' }
    @{ Id = 'Git.Git';                      Name = 'Git' }
    @{ Id = 'BurntSushi.ripgrep.MSVC';      Name = 'ripgrep' }
    @{ Id = 'sharkdp.fd';                   Name = 'fd' }
    @{ Id = 'JesseDuffield.lazygit';        Name = 'lazygit' }
    @{ Id = 'junegunn.fzf';                 Name = 'fzf' }
    @{ Id = 'ajeetdsouza.zoxide';           Name = 'zoxide' }
    @{ Id = 'sharkdp.bat';                  Name = 'bat' }
    @{ Id = 'OpenJS.NodeJS';                Name = 'Node.js' }
    # The C compiler nvim-treesitter needs to build parsers.
    @{ Id = 'zig.zig';                      Name = 'zig (C compiler)' }
)

# `winget upgrade --all` would drag every unrelated program on the machine
# along. This upgrades the stack and nothing else, and asks first: `winget list
# --upgrade-available` exits 0 only when there IS one, so a package that is
# already current never runs an installer.
function Update-TermstackPackages {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Warn "winget missing - skipping the tool upgrades"
        return
    }

    foreach ($p in $TermstackPackages) {
        winget list --id $p.Id --exact --upgrade-available `
            --accept-source-agreements --disable-interactivity *> $null

        if ($LASTEXITCODE -ne 0) { Skip "$($p.Name) up to date"; continue }

        Run "upgrading $($p.Name)"
        winget upgrade --id $p.Id --exact --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity

        if ($LASTEXITCODE -eq 0) {
            Ok "$($p.Name) upgraded"
        } else {
            # Not fatal: an installer that refuses --silent is a nuisance, not a
            # broken machine, and the rest of the update still has to run.
            Warn "$($p.Name): winget exited $LASTEXITCODE - upgrade it by hand"
        }
    }
}

# ---- Neovim plugins ------------------------------------------------------

# install then restore: install brings in what a pulled commit added, restore
# puts every plugin back on the SHA in lazy-lock.json. Same order as
# sync_nvim_plugins in _common.sh -- the lockfile is what keeps the machines
# identical.
#
# No exit-code gate: lazy.nvim exits 0 even with every clone failing.
function Sync-NvimPlugins {
    $nvim = Get-Command nvim -ErrorAction SilentlyContinue
    if (-not $nvim) {
        Warn "nvim not on PATH - open a new terminal, then run:  nvim +Lazy"
        return
    }
    Run "nvim --headless +Lazy! install / restore"
    & $nvim.Source --headless "+Lazy! install" +qa 2>$null
    & $nvim.Source --headless "+Lazy! restore" +qa 2>$null
    Ok "neovim plugins synced with lazy-lock.json"
}

# ---- Snapshot ------------------------------------------------------------

# OUTSIDE the repository, always. These copies carry the user's own $PROFILE,
# which tends to hold work paths and tokens; inside the tree a single .gitignore
# line would be all that stands between them and a public push.
#
# %LOCALAPPDATA% and not ~/.local/state: the native stack keeps its state where
# Windows keeps state, and a Git-Bash/WSL update.sh run on the same box gets its
# own snapshots instead of interleaving with these.
function Get-BackupRoot {
    Join-Path $env:LOCALAPPDATA 'termstack\backup'
}

function New-Snapshot {
    param([string] $RepoDir)

    $snap = Join-Path (Get-BackupRoot) (Get-Date -Format 'yyyyMMdd-HHmmss')
    New-Item -ItemType Directory -Path $snap -Force | Out-Null

    $rev = & git -C $RepoDir rev-parse HEAD 2>$null
    if (-not $rev) { $rev = 'none' }
    Write-Utf8 (Join-Path $snap 'git-rev') "$rev`n"

    # machine.lua is not versioned: if it disappears, it is gone for good.
    $machine = Join-Path $RepoDir 'machine.lua'
    if (Test-Path $machine) { Copy-Item $machine $snap }

    # The lockfile is what gives every machine the same plugin SHAs.
    foreach ($f in @('lazy-lock.json', 'lazyvim.json')) {
        $src = Join-Path $RepoDir "nvim\$f"
        if (Test-Path $src) { Copy-Item $src $snap }
    }

    # The user's $PROFILE. The wiring only appends a marked block and never
    # rewrites the rest, but that file tends to carry SDK paths and work
    # variables that exist nowhere else: losing it is losing it for good.
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) { Copy-Item $profilePath (Join-Path $snap 'profile.ps1') }

    $zellijCfg = Join-Path (Get-ZellijConfigDir) 'config.kdl'
    if (Test-Path $zellijCfg) { Copy-Item $zellijCfg (Join-Path $snap 'zellij-config.kdl') }

    # Tool versions, so you can re-pin by hand if an upgrade breaks something.
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        $versions = winget list --accept-source-agreements --disable-interactivity 2>$null
        Write-Utf8 (Join-Path $snap 'winget-versions.txt') ((@($versions) -join "`n") + "`n")
    }

    # Where the links used to point.
    $lines = @(
        "nvim   -> $(Get-LinkTarget (Get-NvimConfigLink))"
        "zellij -> $(Get-ZellijConfigDir)"
        "pwsh   -> $profilePath"
        "wezterm config file -> $($env:WEZTERM_CONFIG_FILE)"
    )
    Write-Utf8 (Join-Path $snap 'links.txt') (($lines -join "`n") + "`n")

    return $snap
}

# Only the update's own directories count, hence the timestamp pattern: anything
# else that ever writes under the backup root stays out of the rotation.
function Get-Snapshots {
    $root = Get-BackupRoot
    if (-not (Test-Path $root)) { return @() }
    return @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name)
}

function Get-LatestSnapshot {
    # @(): PowerShell unrolls a returned empty array into $null and a
    # one-element array into the element itself. Without the wrapper, .Count on
    # the first run of a fresh machine throws under StrictMode.
    $all = @(Get-Snapshots)
    if ($all.Count -eq 0) { return $null }
    return $all[-1].FullName
}

function Remove-OldSnapshots {
    param([int] $Keep = 5)
    $all = @(Get-Snapshots)
    if ($all.Count -le $Keep) { return }
    foreach ($d in $all[0..($all.Count - $Keep - 1)]) {
        Remove-Item -Recurse -Force $d.FullName -ErrorAction SilentlyContinue
    }
}

# git-rev, and not just "is it a directory": a directory that happens to sit
# under the backup root is not a snapshot, and restoring from it would print
# "restoring" while restoring nothing.
function Test-Snapshot {
    param([string] $Snapshot)
    if (-not $Snapshot) { return $false }
    return (Test-Path (Join-Path $Snapshot 'git-rev'))
}

function Restore-Snapshot {
    param([string] $Snapshot, [string] $RepoDir)

    if (-not (Test-Snapshot $Snapshot)) {
        Bad "no snapshot to restore from"
        return $false
    }

    Section "rollback"
    Run "restoring $Snapshot"

    $rev = (Get-Content (Join-Path $Snapshot 'git-rev') -Raw).Trim()

    if ($rev -and $rev -ne 'none') {
        # `reset --hard` wipes uncommitted changes to TRACKED files, including
        # ones that were already there before the update and that this script
        # never touched. A dirty tree is a normal state here, and on the offline
        # path no pull happened at all: resetting would destroy work for
        # nothing.
        & git -C $RepoDir diff --quiet HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            & git -C $RepoDir reset --hard -q $rev 2>$null
            if ($LASTEXITCODE -eq 0) { Ok "repository back at $rev" }
            else { Warn "could not reset the repository to $rev" }
        } else {
            Warn "the repository has uncommitted changes - NOT resetting"
            Note "your changes are worth more than this rollback; reset by hand if you want to:"
            Note "git -C `"$RepoDir`" stash && git -C `"$RepoDir`" reset --hard $rev"
        }
    }

    $machine = Join-Path $Snapshot 'machine.lua'
    if (Test-Path $machine) { Copy-Item $machine (Join-Path $RepoDir 'machine.lua') -Force; Ok "machine.lua restored" }

    foreach ($f in @('lazy-lock.json', 'lazyvim.json')) {
        $src = Join-Path $Snapshot $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $RepoDir "nvim\$f") -Force; Ok "$f restored" }
    }

    # The wiring is derived from the repo, so it has to be redone AFTER the
    # reset: the generated zellij config would otherwise still be the one built
    # from the bad commit.
    Set-TermstackWiring $RepoDir

    # Puts the Neovim plugins back on the SHAs of the restored lockfile.
    Sync-NvimPlugins

    if (Test-Path (Join-Path $Snapshot 'winget-versions.txt')) {
        Note "tool versions are not reverted; the previous ones are in:"
        Note (Join-Path $Snapshot 'winget-versions.txt')
    }

    return $true
}

# ---- Verification --------------------------------------------------------

# The check.sh of the Windows side: does the stack actually load? It is what
# decides whether an update stays or gets rolled back, so it checks behaviour
# (wezterm really parsing the config) and not just "the file is there".
function Test-TermstackStack {
    param([string] $RepoDir)

    $script:CheckFailures = 0

    Section "wezterm"
    $weztermBin = Get-Command wezterm.exe -ErrorAction SilentlyContinue
    if (-not $weztermBin) {
        Skip "wezterm not on PATH yet - open a new terminal"
    } else {
        # Why not the exit code: `wezterm show-keys` exits 0 even with a broken
        # config -- it silently falls back to the DEFAULT config. The reliable
        # signal is the `Leader:` line, which this repo's config always defines.
        $out = [IO.Path]::GetTempFileName()
        $rc = Invoke-Timed -FilePath $weztermBin.Source -Seconds 20 -StdOut $out `
            -ArgumentList @('--config-file', (Join-Path $RepoDir 'wezterm.lua'), 'show-keys')
        $keys = if (Test-Path $out) { Get-Content $out -Raw } else { '' }
        Remove-Item $out -ErrorAction SilentlyContinue

        if ($rc -eq 142) {
            Bad "wezterm hung reading the config"; $script:CheckFailures++
        } elseif ($keys -match '(?m)^Leader:') {
            Ok "wezterm loads the config"
        } else {
            Bad "wezterm fell back to the default config"; $script:CheckFailures++
        }

        # WITH the LEADER prefix: wezterm's own defaults also bind
        # SplitHorizontal and friends, so searching for the action alone would
        # pass even with the config fallen back.
        foreach ($binding in @('SplitHorizontal', 'SplitVertical', 'ActivateCopyMode', 'TogglePaneZoomState')) {
            if ($keys -match "(?m)LEADER.*$binding") {
                Ok "binding $binding"
            } else {
                Bad "binding $binding missing"; $script:CheckFailures++
            }
        }
    }

    Section "zellij"
    $generated = Join-Path (Get-ZellijConfigDir) 'config.kdl'
    if (-not (Test-Path $generated)) {
        Bad "the generated zellij config is missing"; $script:CheckFailures++
    } else {
        # Drift: a pull that changed zellij/config.kdl without the generated
        # copy being rewritten leaves the terminal running the OLD keybinds,
        # with nothing on screen to say so.
        if ((Get-Content $generated -Raw) -eq (Get-ZellijConfigText $RepoDir)) {
            Ok "generated zellij config matches the repo"
        } else {
            Bad "the generated zellij config is stale - re-run the update"; $script:CheckFailures++
        }
    }

    $zellijBin = Get-Command zellij -ErrorAction SilentlyContinue
    if (-not $zellijBin) {
        Skip "zellij not on PATH yet"
    } else {
        $env:ZELLIJ_CONFIG_DIR = Get-ZellijConfigDir
        & $zellijBin.Source setup --check *> $null
        if ($LASTEXITCODE -eq 0) { Ok "zellij config is valid" }
        else { Bad "zellij setup --check failed"; $script:CheckFailures++ }
        Remove-Item Env:\ZELLIJ_CONFIG_DIR -ErrorAction SilentlyContinue
    }

    # The whole design depends on this: in locked mode zellij captures no key at
    # all, and that is what lets Ctrl+h/j/k/l reach Neovim.
    if ((Get-Content (Join-Path $RepoDir 'zellij\config.kdl') -Raw) -match '(?m)^default_mode "locked"') {
        Ok "zellij starts in locked mode"
    } else {
        Bad "zellij does not start in locked mode"; $script:CheckFailures++
    }

    Section "neovim"
    $target = Get-LinkTarget (Get-NvimConfigLink)
    if (Test-SamePath $target (Join-Path $RepoDir 'nvim')) {
        Ok "$(Get-NvimConfigLink) points at the repo"
    } else {
        Bad "$(Get-NvimConfigLink) does not point at $RepoDir\nvim"; $script:CheckFailures++
    }

    # LazyVim maps <C-h/j/k/l> to <C-w>h/j/k/l on its own. A multiplexer
    # navigation plugin landing here is a regression: every one that exists
    # today has broken detection on Zellij >= 0.42.2.
    $nav = Get-ChildItem (Join-Path $RepoDir 'nvim') -Recurse -File -ErrorAction SilentlyContinue |
        Select-String -Pattern 'zellij-nav|vim-zellij-navigator|smart-splits' -List -ErrorAction SilentlyContinue
    if ($nav) {
        Bad "a multiplexer navigation plugin is back in nvim/"; $script:CheckFailures++
    } else {
        Ok "no multiplexer navigation plugin in nvim/"
    }

    Section "pwsh"
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileText = if (Test-Path $profilePath) { [IO.File]::ReadAllText($profilePath) } else { '' }
    if ($profileText -match '# >>> termstack >>>' -and $profileText -match [regex]::Escape("$RepoDir\pwsh\profile.ps1")) {
        Ok "the pwsh profile loads this repo"
    } else {
        Bad "the pwsh profile does not load $RepoDir\pwsh\profile.ps1"; $script:CheckFailures++
    }

    Section "tools"
    foreach ($t in @('nvim', 'rg', 'fd', 'lazygit')) {
        # A warning, not a failure: right after a winget install the PATH of
        # THIS process is stale, and rolling the machine back over that would be
        # absurd.
        if (Get-Command $t -ErrorAction SilentlyContinue) { Ok "$t on PATH" }
        else { Warn "$t not on PATH - open a new terminal" }
    }

    Section "repository"
    & git -C $RepoDir check-ignore -q machine.lua 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "machine.lua is ignored by git" }
    else { Bad "machine.lua is NOT ignored by git"; $script:CheckFailures++ }

    & git -C $RepoDir ls-files --error-unmatch machine.lua *> $null
    if ($LASTEXITCODE -ne 0) { Ok "machine.lua is untracked" }
    else { Bad "machine.lua is TRACKED - it carries machine-specific paths"; $script:CheckFailures++ }

    # Without these two in git the machines drift apart: the lock pins the
    # plugin SHAs and lazyvim.json records which extras are enabled.
    foreach ($f in @('nvim/lazy-lock.json', 'nvim/lazyvim.json')) {
        if (-not (Test-Path (Join-Path $RepoDir $f))) { Skip "$f absent"; continue }
        & git -C $RepoDir ls-files --error-unmatch $f *> $null
        if ($LASTEXITCODE -eq 0) { Ok "$f is tracked" }
        else { Bad "$f is not tracked"; $script:CheckFailures++ }
    }

    return ($script:CheckFailures -eq 0)
}
