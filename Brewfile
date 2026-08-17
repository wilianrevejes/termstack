# Only what mise does not solve: graphical application and font.
#
# The CLIs (neovim, zellij, tmux, lazygit, ripgrep, fd, fzf, zoxide, bat,
# node) come by way of mise, which
# delivers a prebuilt binary into ~/.local without sudo — the same path on
# the five machines, including the corporate Mac where Homebrew cannot go.

# The stable "wezterm" cask is build 20240203, from February 2024. The
# nightly is the only way to have an up-to-date WezTerm, on any platform.
#
# Careful on upgrade: this cask has `version :latest`, so the ordinary `brew
# upgrade` SKIPS it silently and you end up months behind thinking you are on
# the nightly. scripts/update.sh uses --greedy-latest because of that.
cask "wezterm@nightly"

cask "font-jetbrains-mono-nerd-font"

# Obsidian is here to be *reinstalled*, not upgraded. The cask is
# `auto_updates`, so `brew upgrade` skips it on purpose — the app updates
# itself hourly by downloading a new .asar into
# ~/Library/Application Support/obsidian and loading that at next launch.
#
# So the bundle's CFBundleShortVersionString goes stale while the running
# version moves on: it read 1.12.7 for months while the app ran 1.13.7. Never
# read the Info.plist to find out which version is running — use the log at
# ~/Library/Application Support/obsidian/obsidian.log, or Settings -> About.
#
# Nothing is lost by reinstalling: vaults live in iCloud and settings in
# Application Support, neither of which is inside the bundle.
cask "obsidian"
