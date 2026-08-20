# windows-units.ps1 -- the unit half of the Windows suite.
#
# tests/run.sh calls this and turns every line printed here into a suite line.
# One pwsh process for the whole file, on purpose: starting one per check costs
# half a second each, and what is exercised here are pure functions plus a
# throwaway %LOCALAPPDATA%.
#
# The protocol is one line per check:
#   ok|<description>
#   no|<description>|<detail>
# Anything else on stdout is a crash, and run.sh reports it as a failure.
#
# Nothing here touches the real machine: %LOCALAPPDATA% is redirected to a temp
# directory before the first call, so the snapshot functions write there.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = $env:TS_REPO
if (-not $repo) { "no|windows units|TS_REPO is not set"; exit 1 }

$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("termstack-test-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$realLocalAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = $sandbox

. (Join-Path $repo 'scripts\_common-windows.ps1')

# A check is a scriptblock whose LAST value is the verdict; it can set
# $script:Detail to say why it failed. An exception is a failure with the
# message attached, never a silent pass.
$script:Detail = ''
function Check {
    param([string] $Desc, [scriptblock] $Body)
    $script:Detail = ''
    try {
        $out = @(& $Body)
        $verdict = if ($out.Count) { $out[-1] } else { $false }
        if ($verdict -eq $true) {
            "ok|$Desc"
        } elseif ($script:Detail) {
            "no|$Desc|$($script:Detail)"
        } else {
            "no|$Desc|verdict was '$verdict'"
        }
    } catch {
        "no|$Desc|$($_.Exception.Message)"
    }
}

function New-FakeSnapshot {
    param([string] $Name, [switch] $NoGitRev)
    $d = Join-Path (Get-BackupRoot) $Name
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    if (-not $NoGitRev) { Write-Utf8 (Join-Path $d 'git-rev') "deadbeef`n" }
    return $d
}

# ---- snapshot bookkeeping ------------------------------------------------

# A directory that merely SITS under the backup root is not a snapshot. On Unix
# this exact hole made `--rollback` print "restoring" and restore nothing: the
# preflight directories passed the -d test and had no git-rev at all.
Check "Test-Snapshot rejects a directory with no git-rev" {
    $d = New-FakeSnapshot -Name '20200101-000000' -NoGitRev
    (Test-Snapshot $d) -eq $false
}

Check "Test-Snapshot accepts a directory with git-rev" {
    $d = New-FakeSnapshot -Name '20200102-000000'
    (Test-Snapshot $d) -eq $true
}

Check "Test-Snapshot rejects an empty path" {
    (Test-Snapshot '') -eq $false
}

# A fresh machine has no backup root at all. Returning an empty array from a
# PowerShell function unrolls it to $null, and `$null.Count` throws under
# StrictMode -- which is exactly how the first run of the script died.
Check "Get-LatestSnapshot survives an empty backup root" {
    $empty = Join-Path $sandbox 'empty'
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    $keep = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = $empty
    try { $null -eq (Get-LatestSnapshot) } finally { $env:LOCALAPPDATA = $keep }
}

Check "Get-LatestSnapshot picks the newest timestamp" {
    New-FakeSnapshot -Name '20260101-120000' | Out-Null
    New-FakeSnapshot -Name '20260301-090000' | Out-Null
    New-FakeSnapshot -Name '20260201-235959' | Out-Null
    (Split-Path -Leaf (Get-LatestSnapshot)) -eq '20260301-090000'
}

# The rotation only ever looks at its OWN directories. Anything else under the
# backup root -- a hand-made copy, a directory from another tool -- must survive
# the prune untouched: on Unix the only copy of the user's ~/.zshrc lived in one
# of those.
Check "Remove-OldSnapshots keeps the 5 newest and ignores foreign directories" {
    Remove-Item -Recurse -Force (Get-BackupRoot) -ErrorAction SilentlyContinue
    foreach ($n in 1..8) { New-FakeSnapshot -Name ("2026010{0}-000000" -f $n) | Out-Null }
    $foreign = Join-Path (Get-BackupRoot) 'preflight-manual'
    New-Item -ItemType Directory -Path $foreign -Force | Out-Null

    Remove-OldSnapshots -Keep 5

    $left = @(Get-Snapshots | ForEach-Object { $_.Name })
    ($left.Count -eq 5) -and
    ($left[0] -eq '20260104-000000') -and
    ($left[-1] -eq '20260108-000000') -and
    (Test-Path $foreign)
}

Check "Remove-OldSnapshots does nothing below the limit" {
    Remove-Item -Recurse -Force (Get-BackupRoot) -ErrorAction SilentlyContinue
    foreach ($n in 1..3) { New-FakeSnapshot -Name ("2026020{0}-000000" -f $n) | Out-Null }
    Remove-OldSnapshots -Keep 5
    @(Get-Snapshots).Count -eq 3
}

# ---- the snapshot itself -------------------------------------------------

# It carries a copy of the user's $PROFILE, which tends to hold work paths: it
# has to land OUTSIDE the repository, where no .gitignore line is the only thing
# between it and a public push.
Check "the backup root is outside the repository" {
    -not ((Get-BackupRoot).StartsWith($repo, [StringComparison]::OrdinalIgnoreCase))
}

Check "New-Snapshot records the git rev and the wiring" {
    Remove-Item -Recurse -Force (Get-BackupRoot) -ErrorAction SilentlyContinue
    $snap = New-Snapshot $repo
    $rev = (Get-Content (Join-Path $snap 'git-rev') -Raw).Trim()
    (Test-Snapshot $snap) -and
    ($rev -match '^[0-9a-f]{40}$') -and
    (Test-Path (Join-Path $snap 'links.txt'))
}

# lazy-lock.json is what keeps every machine on the same plugin SHAs: a rollback
# that does not restore it puts the plugins back on whatever the bad commit
# pinned.
Check "New-Snapshot copies the nvim lockfiles" {
    $snap = Get-LatestSnapshot
    (Test-Path (Join-Path $snap 'lazy-lock.json')) -and
    (Test-Path (Join-Path $snap 'lazyvim.json'))
}

# ---- the timeout ---------------------------------------------------------

# Without this the update hangs forever on a `git ls-remote` against a remote
# that never answers, and there is no Ctrl+C in an unattended run.
Check "Invoke-Timed kills a command that outlives the deadline" {
    $pwshExe = (Get-Process -Id $PID).Path
    (Invoke-Timed -FilePath $pwshExe -Seconds 1 `
        -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 20')) -eq 142
}

Check "Invoke-Timed hands back the real exit code" {
    (Invoke-Timed -FilePath 'cmd.exe' -Seconds 20 -ArgumentList @('/c', 'exit 7')) -eq 7
}

# ---- paths ---------------------------------------------------------------

# The junction check compares what Get-Item hands back against the repo path,
# and Windows hands it back in whatever case and with whatever trailing slash it
# feels like.
Check "Test-SamePath ignores case and a trailing slash" {
    (Test-SamePath 'C:\Temp\x' 'c:\temp\x\') -and
    (-not (Test-SamePath 'C:\Temp\x' 'C:\Temp\y')) -and
    (-not (Test-SamePath '' 'C:\Temp\x'))
}

# ---- the package list ----------------------------------------------------

# One list, so update-windows.ps1 upgrades exactly what bootstrap-windows.ps1
# installs. Two copies is how a tool gets installed on new machines and never
# upgraded on the old ones.
Check "the winget package list is shared and complete" {
    $ids = @($TermstackPackages | ForEach-Object { $_.Id })
    $bootstrap = [IO.File]::ReadAllText((Join-Path $repo 'scripts\bootstrap-windows.ps1'))
    ($ids.Count -ge 13) -and
    ($ids -contains 'wez.wezterm') -and
    ($ids -contains 'Neovim.Neovim') -and
    ($ids -contains 'Zellij.Zellij') -and
    (@($TermstackPackages | Where-Object { -not $_.Name }).Count -eq 0) -and
    ($bootstrap -match '\$TermstackPackages') -and
    ($bootstrap -notmatch 'Install-IfMissing -Id "')
}

# The update is the one command per machine, and the list grows: a package added
# after a machine was bootstrapped has to ARRIVE on the next update, not be
# reported as up to date. Without `winget install` in there, it never does.
Check "the update installs a package that is missing, not only upgrades" {
    $common = [IO.File]::ReadAllText((Join-Path $repo 'scripts\_common-windows.ps1'))
    $fn = [regex]::Match($common, '(?ms)^function Update-TermstackPackages \{.*?^\}').Value
    $script:Detail = if ($fn) { 'Update-TermstackPackages no longer installs what is missing' } else { 'Update-TermstackPackages not found' }
    ($fn -match 'winget install --id') -and
    ($fn -match '\$script:TermstackInstalled') -and
    # The gate that was wrong: its exit code answers "is it installed", never
    # "is there an upgrade".
    ($fn -notmatch 'list .*--upgrade-available')
}

# ---- winget's exit codes -------------------------------------------------

# The two codes that are ANSWERS and not failures. Reading them as failures is
# what made the update announce "up to date" for packages that had never been
# installed -- and then never install them: a machine ran this stack for weeks
# with no Zellij and no Neovim, and every update said everything was fine.
Check "Get-WingetOutcome tells 'no upgrade' from 'not installed' from a real failure" {
    ((Get-WingetOutcome 0) -eq 'ok') -and
    ((Get-WingetOutcome -1978335189) -eq 'current') -and   # 0x8A15002B
    ((Get-WingetOutcome -1978335212) -eq 'missing') -and   # 0x8A150014
    ((Get-WingetOutcome 1) -eq 'failed')
}

# The names have to keep matching the codes: a typo in either constant turns a
# current package into a warning and a missing one into a silent skip again.
Check "the named winget codes are the documented ones" {
    ($WingetNoUpgrade -eq -1978335189) -and
    ($WingetNotInstalled -eq -1978335212)
}

# ---- the process PATH ----------------------------------------------------

# It runs right after winget installed Neovim, with the plugin sync and the
# whole verification still to come. It may only ADD: a replacement would drop
# whatever this process carries that the registry does not, and take git or
# winget itself down with it.
Check "Update-ProcessPath only ever adds to PATH" {
    $marker = Join-Path $sandbox 'only-in-this-process'
    $env:PATH = "$marker;$env:PATH"
    $before = @($env:PATH -split ';' | Where-Object { $_ })

    Update-ProcessPath

    $after = @($env:PATH -split ';' | Where-Object { $_ })
    $dropped = @($before | Where-Object { $after -notcontains $_ })
    $script:Detail = "dropped: " + ($dropped -join ', ')
    ($dropped.Count -eq 0) -and ($after -contains $marker)
}

# setup calls it after the install and update calls it after the upgrades: on a
# machine where nothing new landed, the second call must not keep growing PATH.
Check "Update-ProcessPath is idempotent" {
    Update-ProcessPath
    $once = $env:PATH
    Update-ProcessPath
    $env:PATH -eq $once
}

# ---- name collisions -----------------------------------------------------

# PowerShell resolves an ALIAS before a function, so `function Group {...}`
# followed by `Group "next steps"` silently ran Group-Object and printed
# nothing. It shipped that way and no output ever said so.
Check "no helper function is shadowed by a built-in alias" {
    $shadowed = @()
    foreach ($f in @('_common-windows.ps1', 'setup-windows.ps1', 'update-windows.ps1', 'bootstrap-windows.ps1')) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $repo "scripts\$f"), [ref] $tokens, [ref] $errors)
        foreach ($fn in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            if (Get-Alias -Name $fn.Name -ErrorAction SilentlyContinue) { $shadowed += "$f : $($fn.Name)" }
        }
    }
    $script:Detail = $shadowed -join ', '
    $shadowed.Count -eq 0
}

# ---- the wiring, end to end ----------------------------------------------

# Against a FAKE repository, never the real one: a test that seeds machine.lua
# or rewrites a config in the working tree is a test that changes the thing it
# is measuring. %LOCALAPPDATA%, %APPDATA% and $PROFILE all point into the
# sandbox, so the junction, the generated zellij config and the profile block
# land there.
$fake = Join-Path $sandbox 'repo'
New-Item -ItemType Directory -Path (Join-Path $fake 'nvim') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fake 'pwsh') -Force | Out-Null
Copy-Item (Join-Path $repo 'machine.example.lua') $fake
Copy-Item (Join-Path $repo 'zellij') $fake -Recurse
Copy-Item (Join-Path $repo 'nvim\lazy-lock.json') (Join-Path $fake 'nvim')
Copy-Item (Join-Path $repo 'nvim\lazyvim.json') (Join-Path $fake 'nvim')
Write-Utf8 (Join-Path $fake 'pwsh\profile.ps1') "# fake`n"

$env:APPDATA = Join-Path $sandbox 'appdata'
$fakeProfile = Join-Path $sandbox 'Documents\PowerShell\profile.ps1'
$PROFILE = [PSCustomObject] @{ CurrentUserAllHosts = $fakeProfile }

# Write-Host goes to the information stream (6): swallow it, or the helpers'
# output would land in the middle of this file's ok|/no| protocol.
Check "Set-TermstackWiring seeds machine.lua, the junction, the zellij config and the profile" {
    Set-TermstackWiring $fake 6>$null
    $link = Get-LinkTarget (Get-NvimConfigLink)
    $kdl  = Join-Path (Get-ZellijConfigDir) 'config.kdl'
    (Test-Path (Join-Path $fake 'machine.lua')) -and
    (Test-SamePath $link (Join-Path $fake 'nvim')) -and
    (Test-Path $kdl) -and
    ((Get-Content $kdl -Raw) -eq (Get-ZellijConfigText $fake)) -and
    ([IO.File]::ReadAllText($fakeProfile) -match '# >>> termstack >>>')
}

# The update runs on machines that are already set up: a second run must leave
# ONE block, not two, and must not re-link over a link that is already right.
Check "Set-TermstackWiring is idempotent" {
    Set-TermstackWiring $fake 6>$null
    Set-TermstackWiring $fake 6>$null
    $text = [IO.File]::ReadAllText($fakeProfile)
    $blocks = ([regex]::Matches($text, '# >>> termstack >>>')).Count
    $blocks -eq 1
}

# The profile is the user's file. It carries work variables that exist nowhere
# else, and the marked block is the only part this repo owns.
Check "Install-PwshProfile keeps what was already in the profile" {
    Write-Utf8 $fakeProfile "`$env:MY_SDK = 'x'`n"
    Install-PwshProfile $fake 6>$null
    Install-PwshProfile $fake 6>$null
    $text = [IO.File]::ReadAllText($fakeProfile)
    ($text -match "MY_SDK") -and
    (([regex]::Matches($text, '# >>> termstack >>>')).Count -eq 1)
}

# The central promise of link_config, kept on the Windows side: a real directory
# where the link should go is never overwritten.
Check "New-ConfigJunction refuses to clobber a real directory" {
    $real = Join-Path $sandbox 'realdir'
    New-Item -ItemType Directory -Path $real -Force | Out-Null
    Write-Utf8 (Join-Path $real 'mine.txt') "do not delete`n"
    New-ConfigJunction $real (Join-Path $fake 'nvim') 'test' 6>$null
    (Test-Path (Join-Path $real 'mine.txt')) -and
    ($null -eq (Get-LinkTarget $real))
}

# ---- the rollback --------------------------------------------------------

# What the whole snapshot exists for: a bad update must be undoable. machine.lua
# is not versioned and the lockfile is what pins the plugin SHAs -- if these two
# do not come back, the rollback restored nothing that matters.
Check "Restore-Snapshot puts machine.lua and the lockfile back" {
    Write-Utf8 (Join-Path $fake 'machine.lua') "-- good`n"
    $snap = New-Snapshot $fake

    Write-Utf8 (Join-Path $fake 'machine.lua') "-- BAD`n"
    Write-Utf8 (Join-Path $fake 'nvim\lazy-lock.json') "{ `"broken`": true }`n"

    $restored = Restore-Snapshot $snap $fake 6>$null

    ($restored -eq $true) -and
    ((Get-Content (Join-Path $fake 'machine.lua') -Raw).Trim() -eq '-- good') -and
    ((Get-Content (Join-Path $fake 'nvim\lazy-lock.json') -Raw) -notmatch 'broken')
}

Check "Restore-Snapshot refuses a directory that is not a snapshot" {
    $notSnap = Join-Path $sandbox 'not-a-snapshot'
    New-Item -ItemType Directory -Path $notSnap -Force | Out-Null
    (Restore-Snapshot $notSnap $fake 6>$null) -eq $false
}

# ---- cleanup -------------------------------------------------------------

$env:LOCALAPPDATA = $realLocalAppData
Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
