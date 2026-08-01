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
