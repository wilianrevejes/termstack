# update-windows.ps1 -- one command per machine, for the NATIVE Windows stack.
#
#   .\scripts\update-windows.ps1             update everything
#   .\scripts\update-windows.ps1 -DryRun     diagnose only; change nothing
#   .\scripts\update-windows.ps1 -Rollback   go back to the latest snapshot
#   .\scripts\update-windows.ps1 -Rollback -Snapshot <dir>
#   .\scripts\update-windows.ps1 -Help       this help
#
# The counterpart of update.sh, which is Unix-only: it links into ~/.config,
# drives mise/brew and updates zsh, oh-my-zsh and tmux -- none of which is the
# native Windows stack. Here the wiring is junctions plus a generated zellij
# config, and the tools come from winget.
#
# Before touching anything it takes a snapshot. If the final verification fails,
# it rolls back on its own -- the machine does not stay broken because a bad
# commit arrived through the pull.
#
# Nothing aborts on a failing network step, on purpose: what matters -- the
# wiring and the local config -- runs even offline.

param(
    [switch] $DryRun,
    [switch] $Rollback,
    [string] $Snapshot,
    [switch] $Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "This script must be run on Windows."
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$repoDir = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot '_common-windows.ps1')

# Never let git open an interactive credential prompt: this script runs
# unattended (and behind a timeout), and a prompt would just hang until the
# alarm kills it. A credential manager still answers.
$env:GIT_TERMINAL_PROMPT = '0'

function Show-Usage {
    Write-Host "update-windows.ps1 - updates the native Windows stack, with snapshot and rollback."
    Write-Host ""
    Write-Host "  .\scripts\update-windows.ps1             update everything"
    Write-Host "  .\scripts\update-windows.ps1 -DryRun     diagnose only; change nothing"
    Write-Host "  .\scripts\update-windows.ps1 -Rollback   go back to the latest snapshot"
    Write-Host "  .\scripts\update-windows.ps1 -Rollback -Snapshot <dir>"
    Write-Host "  .\scripts\update-windows.ps1 -Help       this help"
    Write-Host ""
    Write-Host "The zsh/tmux layer is a separate stack: run  bash scripts/update.sh  inside WSL."
}

# ---- Body ----------------------------------------------------------------

if ($Help) { Show-Usage; exit 0 }

if ($args.Count -gt 0) {
    [Console]::Error.WriteLine("Unknown argument: $($args -join ' ')")
    Show-Usage
    exit 64
}

# ---- Rollback mode -------------------------------------------------------

if ($Rollback) {
    Banner "termstack" "rollback"

    $snap = if ($Snapshot) { $Snapshot } else { Get-LatestSnapshot }

    if (-not (Restore-Snapshot $snap $repoDir)) {
        Note "snapshots live in $(Get-BackupRoot)"
        exit 1
    }

    if (Test-TermstackStack $repoDir) {
        ResOk "restored"
        exit 0
    }

    ResWarn "restored, but the stack still does not check out"
    exit 1
}

Banner "termstack" ("update {0} WezTerm {0} Zellij {0} LazyVim {0} pwsh" -f $SymMid)

# ---- Dry run -------------------------------------------------------------

# No network here, and no writes: this is the mode you can run to see what the
# update would touch, including inside a test suite.
if ($DryRun) {
    Section "diagnosis"
    Note "repository  $repoDir"
    $head = & git -C $repoDir rev-parse --short HEAD 2>$null
    if ($head) { Note "at commit   $head" } else { Note "at commit   (not a git repository)" }
    Note "snapshots   $(Get-BackupRoot)"

    $latest = Get-LatestSnapshot
    if ($latest) { Note "latest      $(Split-Path -Leaf $latest)" } else { Note "latest      (none yet)" }

    Section "would do"
    Note "1  snapshot: git rev, machine.lua, the lockfiles, your `$PROFILE, tool versions"
    Note "2  git pull --rebase --autostash"
    Note "3  re-wire: machine.lua, the nvim junction, the zellij config, the pwsh profile"
    Note "4  winget, package by package: install what is missing, upgrade the rest ($($TermstackPackages.Count))"
    Note "5  nvim +Lazy! install / restore, if nvim/ changed in the pull"
    Note "6  verify, and roll back on its own if the verification fails"

    ResOk "diagnose only (dry run)"
    exit 0
}

# ---- 1. Snapshot ---------------------------------------------------------

# The probe comes first: an offline machine must not sit waiting on a pull.
$online = $false
$gitBin = Get-Command git -ErrorAction SilentlyContinue
if ($gitBin) {
    $rc = Invoke-Timed -FilePath $gitBin.Source -Seconds 8 `
        -ArgumentList @('-C', $repoDir, 'ls-remote', '--exit-code', 'origin', 'HEAD')
    $online = ($rc -eq 0)
}

$snapshot = New-Snapshot $repoDir
Section "snapshot"
Ok "taken at $snapshot"

$before = & git -C $repoDir rev-parse HEAD 2>$null
if (-not $before) { $before = 'none' }
$after = $before

# ---- 2. Repository -------------------------------------------------------

Section "repository"

if ($online) {
    Run "git pull --rebase --autostash"
    # --autostash: immune to a dirty working tree, which is the number one cause
    # of an update script stalling halfway.
    #
    # Output straight to the terminal, never through a pipeline: PowerShell wraps
    # a native command's REDIRECTED stderr into ErrorRecords, and git says
    # perfectly ordinary things on stderr. Piping it is how an update dies on a
    # message instead of on an error.
    & git -C $repoDir pull --rebase --autostash -q

    $head = & git -C $repoDir rev-parse HEAD 2>$null
    if ($head) { $after = $head }

    if ($before -eq $after) { Skip "already up to date" }
    else { Ok "$(Get-ShortRev $before) -> $(Get-ShortRev $after)" }
} else {
    Skip "offline - keeping the repository as it is"
}

# ---- 3. Wiring. Always, and works offline. -------------------------------

Section "wiring"
Set-TermstackWiring $repoDir

if ($online) {
    # ---- 4. Tools --------------------------------------------------------

    Section "tools"
    Update-TermstackPackages
    # Anything winget installed just now is on the registry PATH, not on this
    # process's. The Neovim step below and the verification both ask
    # `Get-Command`, and both would answer "not here" for a tool sitting on disk.
    Update-ProcessPath

    # ---- 5. Neovim. With a gate: this is the expensive step. -------------

    Section "neovim"
    $nvimChanged = $true
    if ($before -eq $after) {
        $nvimChanged = $false
    } else {
        & git -C $repoDir diff --quiet $before $after -- nvim/ 2>$null
        $nvimChanged = ($LASTEXITCODE -ne 0)
    }

    # A Neovim that the step above installed for the first time has no plugins at
    # all: the pull-diff gate alone would skip it and leave LazyVim unbootstrapped
    # until someone happened to open nvim by hand.
    if ($script:TermstackInstalled -contains 'Neovim.Neovim') { $nvimChanged = $true }

    if ($nvimChanged) { Sync-NvimPlugins }
    else { Skip "nvim/ unchanged - not touching the plugins" }

    # ---- 6. Zellij: nothing to do. ---------------------------------------
    # It watches the active config.kdl and reloads most options in real time,
    # and the wiring above already rewrote the generated file. The plugin cache
    # is versioned per release, so upgrading the binary invalidates it on its
    # own.
}

# ---- 7. Verification, with automatic rollback ----------------------------

Write-Host ""
if (Test-TermstackStack $repoDir) {
    # Prune only after success: pruning first would delete this run's snapshot
    # exactly when the rollback was about to need it.
    Remove-OldSnapshots -Keep 5
    ResOk "termstack is up to date"
    exit 0
}

ResBad "the verification failed - rolling back"

if (-not (Restore-Snapshot $snapshot $repoDir)) { exit 2 }

Write-Host ""
if (Test-TermstackStack $repoDir) {
    ResWarn "rolled back to the previous state"
    Note "the snapshot was kept: $snapshot"
    exit 1
}

ResBad "the rollback did not fix it - this was already broken before the update"
Note "the snapshot was kept: $snapshot"
exit 2
