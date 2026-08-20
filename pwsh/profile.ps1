# termstack -- pwsh profile for the native Windows setup.
#
# This file is NOT your $PROFILE. It is dot-sourced from it by a marked block
# that setup-windows.ps1 writes, so your own $PROFILE stays yours. It is the
# pwsh analogue of zsh/zshrc, minus what is Unix-only (oh-my-zsh, powerlevel10k).
# The CLI tools come from winget and are already on PATH -- node is the one
# exception, and mise below is why.

# Zellij resolves the scrollback editor once, at startup; git/crontab want it
# too. Set it before anything that opens an editor.
$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'

# The same short aliases as the zsh side.
Set-Alias -Name zj  -Value zellij  -ErrorAction SilentlyContinue
Set-Alias -Name v   -Value nvim    -ErrorAction SilentlyContinue
Set-Alias -Name vim -Value nvim    -ErrorAction SilentlyContinue
Set-Alias -Name lg  -Value lazygit -ErrorAction SilentlyContinue

# node comes from mise on every machine, Windows included: its version is a
# per-project fact, and mise/config.toml pins the channel for all five. mise's
# shims are deliberately NOT on PATH -- activating is what puts the pinned node
# there, so without this line `node` is either missing or somebody else's.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    mise activate pwsh | Out-String | Invoke-Expression
}

# z DIR jumps to the most frecent match; zi opens the picker.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# fzf keybindings (Ctrl+R history, Ctrl+T files) come from the optional PSFzf
# module -- imported only if installed. The fzf binary alone still powers any
# `fzf`-based command.
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
}

# The four-layer cheat sheet. Reuses scripts/cheatsheet.sh through Git Bash
# (installed with git) so there is a single source for the sheet on every OS.
# $PSScriptRoot is this file's dir = <repo>/pwsh, so the repo root is its parent.
function stack {
    $sheet = (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/cheatsheet.sh') -replace '\\', '/'
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) { & $bash.Source '-c' "bash '$sheet'" }
    else { Write-Host 'install Git (for Git Bash) to see the cheat sheet' }
}
