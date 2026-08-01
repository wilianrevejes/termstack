#!/usr/bin/env bash
#
# Installs and configures the whole stack on macOS: WezTerm, Zellij, Neovim
# (LazyVim), tmux, and the font.
# Idempotent: run it as many times as you like.
#
# Does not install Homebrew, does not use sudo, does not strip quarantine and
# does not touch security policy — this has to be safe to run on a managed
# work Mac. Where there is no Homebrew, mise handles the CLI tools on its own,
# without sudo.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "$MSG_BOOT_NOT_MACOS" >&2
  exit 1
fi

# ── What already exists here and would get in the way ─────────────────────
# Diagnosis only. It does not abort: the bootstrap degrades on its own —
# whatever is occupied it leaves alone, with a warning. Cleaning is your call.

# This script is called by scripts/setup.sh, which is the entry point: it asks
# before cleaning anything, walks through the steps and offers p10k configure
# at the end. Running this directly works, but you skip all of that.
#
# FROM_SETUP cuts what would duplicate the wizard: this preflight (setup
# already ran and showed its own) and the epilogue (setup's steps 3-5 cover
# everything it would say).
if [[ -z "${TERMSTACK_FROM_SETUP:-}" ]]; then
  ui_group "$MSG_BOOT_GROUP_BEFORE"
  ui_warn "$MSG_BOOT_ENTRY_POINT"
  ui_note "$MSG_BOOT_ENTRY_POINT_NOTE"
  ui_note "$MSG_BOOT_ENTRY_POINT_CMD" "$repo_dir"

  bash "$repo_dir/scripts/preflight.sh" || {
    echo
    ui_note "$MSG_BOOT_PREFLIGHT_FIX"
    ui_note "$MSG_BOOT_PREFLIGHT_FIX_CMD" "$repo_dir"
    ui_note "$MSG_BOOT_CARRY_ON"
  }
fi

# ── CLI ───────────────────────────────────────────────────────────────────

ui_group "$MSG_BOOT_GROUP_CLI"

install_mise
install_tools "$repo_dir"
configure_shell "$repo_dir"

# ── GUI app and font ──────────────────────────────────────────────────────

ui_group "$MSG_BOOT_GROUP_WEZTERM"

if command -v brew >/dev/null 2>&1; then
  # Same as update.sh: no implicit `brew update` (the bundle fetches what it
  # needs as-is) and none of the five lines of env hints.
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1

  ui_run "$MSG_BOOT_BREW_BUNDLE"
  ui_pipe brew bundle --file "$repo_dir/Brewfile"

  # A freshly installed .app bundle that never went through LaunchServices has
  # its command-line binaries blocked by AppleSystemPolicy — and the block
  # raises no error, it hangs in dyld forever. `open -a` once fixes it.
  wezterm_app=/Applications/WezTerm.app
  if [[ -d "$wezterm_app" ]]; then
    ui_run "$MSG_BOOT_OPEN_ONCE"
    open -a "$wezterm_app" 2>/dev/null || true
    sleep 5
  fi
else
  ui_warn "$MSG_BOOT_NO_BREW"
  msg_boot_no_brew_hint

  # The font does not depend on Homebrew: downloaded from the official
  # release, no sudo. That is what gives the managed Mac the same font as the
  # other machines.
  install_nerd_font
fi

# ── Configuration ─────────────────────────────────────────────────────────

ui_group "$MSG_BOOT_GROUP_LINKS"

seed_machine_lua "$repo_dir"
link_all_configs "$repo_dir"

ui_group "$MSG_BOOT_GROUP_PLUGINS"

ui_run "$MSG_BOOT_ZSH_REPOS"
sync_zsh_repos "$repo_dir" || ui_warn "$MSG_BOOT_ZSH_FAILED"
setup_tmux_plugins "$repo_dir"
sync_nvim_plugins

# Epilogue only when run directly: inside setup, its steps 3-5 and its "Next
# steps" section already say all of this.
if [[ -z "${TERMSTACK_FROM_SETUP:-}" ]]; then
  ui_group "$MSG_BOOT_GROUP_DONE"

  msg_boot_done "$repo_dir"
fi
