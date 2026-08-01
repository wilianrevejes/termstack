#!/usr/bin/env bash
#
# Installs and configures the stack on Linux: WezTerm, Zellij, Neovim
# (LazyVim), tmux, and the font.
# Idempotent: run it as many times as you like.
#
# Inside WSL it skips WezTerm and the font — rendering there is done by the
# Windows WezTerm. Run this script inside the distro to get the CLI tools and
# the configs.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "$MSG_BOOT_NOT_LINUX" >&2
  exit 1
fi

distro_id() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    (source /etc/os-release && echo "${ID:-unknown}")
  else
    echo unknown
  fi
}

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
# Always through mise, Arch included. apt has neither zellij nor wezterm in
# any version, and ships neovim, lazygit, fd and ripgrep behind; dnf has
# neither zellij nor lazygit. One single path across five machines is worth
# more than optimizing per distro.

ui_group "$MSG_BOOT_GROUP_CLI"

install_mise
install_tools "$repo_dir"
configure_shell "$repo_dir"

# ── WezTerm (not under WSL) ───────────────────────────────────────────────

ui_group "$MSG_BOOT_GROUP_WEZTERM"

if is_wsl; then
  ui_skip "$MSG_BOOT_WSL_SKIP"
elif command -v wezterm >/dev/null 2>&1; then
  ui_skip "$MSG_BOOT_WEZTERM_PRESENT" "$(wezterm --version)"
else
  # Stable in every repository is the February 2024 build. Where a nightly or
  # git package exists, that is the one that means "latest version".
  case "$(distro_id)" in
    arch | manjaro | endeavouros)
      ui_run "$MSG_BOOT_PACMAN"
      sudo pacman -S --needed wezterm
      ui_note "$MSG_BOOT_PACMAN_NOTE"
      ;;

    ubuntu | debian | pop | linuxmint)
      ui_run "$MSG_BOOT_APT"
      curl -fsSL https://apt.fury.io/wez/gpg.key |
        sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
      echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' |
        sudo tee /etc/apt/sources.list.d/wezterm.list
      sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
      sudo apt update
      sudo apt install -y wezterm
      ;;

    fedora | rhel | centos)
      ui_run "$MSG_BOOT_COPR"
      sudo dnf copr enable -y wezfurlong/wezterm-nightly
      sudo dnf install -y wezterm
      ;;

    opensuse* | sles)
      ui_run "$MSG_BOOT_ZYPPER"
      sudo zypper install -y wezterm
      ;;

    *)
      ui_warn "$MSG_BOOT_NO_DISTRO"
      ui_note "$MSG_BOOT_APPIMAGE"
      ;;
  esac
fi

# ── Font ──────────────────────────────────────────────────────────────────
# From the official release, straight into ~/.local/share/fonts. No two
# distros name a Nerd Font package the same, but the download is one single
# path for all of them — and needs no sudo.
#
# Under WSL the font is installed on Windows: rendering is done by WezTerm
# over there.

if ! is_wsl; then
  install_nerd_font
fi

# ── Configuration ─────────────────────────────────────────────────────────

ui_group "$MSG_BOOT_GROUP_LINKS"

seed_machine_lua "$repo_dir"

if is_wsl; then
  # No WezTerm here, so no WezTerm config link.
  link_config "$repo_dir/zellij" "$HOME/.config/zellij"
  link_config "$repo_dir/nvim" "$HOME/.config/nvim"
  link_config "$repo_dir/tmux" "$HOME/.config/tmux" "$HOME/.tmux.conf"
else
  link_all_configs "$repo_dir"
fi

ui_group "$MSG_BOOT_GROUP_PLUGINS"

ui_run "$MSG_BOOT_ZSH_REPOS"
sync_zsh_repos "$repo_dir" || ui_warn "$MSG_BOOT_ZSH_FAILED"
setup_tmux_plugins "$repo_dir"
sync_nvim_plugins

# Epilogue only when run directly: inside setup, its steps 3-5 and its "Next
# steps" section already say all of this.
if [[ -z "${TERMSTACK_FROM_SETUP:-}" ]]; then
  ui_group "$MSG_BOOT_GROUP_DONE"

  msg_boot_linux_done "$repo_dir"
fi
