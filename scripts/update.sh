#!/usr/bin/env bash
#
# One command per machine: updates the repository and then WezTerm, Zellij,
# Neovim (LazyVim) and tmux.
#
#   bash scripts/update.sh              update everything
#   bash scripts/update.sh --rollback   go back to the latest snapshot
#
# Before touching anything it takes a snapshot of the current state. If the
# final verification fails, it rolls back to the snapshot on its own — the
# machine does not stay broken because a bad commit arrived through the pull.
#
# No `set -e`, on purpose: a failing network step must not kill the script
# halfway. What matters — links and local configuration — runs even offline.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

backup_root="$(backup_root)"
keep_snapshots=5

# ── Snapshot ──────────────────────────────────────────────────────────────

take_snapshot() {
  local snap
  snap="$backup_root/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$snap"

  git -C "$repo_dir" rev-parse HEAD >"$snap/git-rev" 2>/dev/null ||
    echo none >"$snap/git-rev"

  # machine.lua is not versioned: if it disappears, it is gone for good.
  [[ -f "$repo_dir/machine.lua" ]] && cp "$repo_dir/machine.lua" "$snap/"

  # The lockfile is what gives every machine the same plugin SHAs.
  [[ -f "$repo_dir/nvim/lazy-lock.json" ]] &&
    cp "$repo_dir/nvim/lazy-lock.json" "$snap/"
  [[ -f "$repo_dir/nvim/lazyvim.json" ]] &&
    cp "$repo_dir/nvim/lazyvim.json" "$snap/"

  # The shell rc files. The bootstrap only appends a marked block and never
  # rewrites, but these files tend to carry SDK paths and work variables that
  # exist nowhere else: losing them is losing them for good.
  mkdir -p "$snap/shell"
  local f
  for f in .zshrc .zshenv .zprofile .zlogin .bashrc .bash_profile .zshrc.local; do
    [[ -f "$HOME/$f" ]] && cp "$HOME/$f" "$snap/shell/$f"
  done

  # Tool versions, so you can re-pin by hand if an upgrade breaks something.
  local mise
  mise="$(mise_bin)"
  [[ -n "$mise" ]] && "$mise" ls --current >"$snap/mise-versions.txt" 2>/dev/null

  # Where the links used to point.
  {
    local p
    for p in wezterm zellij nvim tmux; do
      printf '%s -> %s\n' "$p" "$(readlink "$HOME/.config/$p" 2>/dev/null || echo '(not a link)')"
    done
  } >"$snap/links.txt"

  echo "$snap"
}

# Only the update's own directories count, hence the [0-9]* glob: preflight
# writes into the same backup_root with a `preflight-` prefix, and what sits
# there is the ONLY copy of the ~/.zshrc and ~/.config/nvim that --clean took
# away.
#
# `head -n -N` (a negative count) is a GNU extension. BSD head answers
# "illegal line count" on stderr — which was not redirected — and pruned
# nothing: on macOS this function was noise on every run, and a no-op.
prune_snapshots() {
  local n
  # shellcheck disable=SC2012  # names are timestamps, no spaces or newlines
  n="$(ls -1d "$backup_root"/[0-9]*/ 2>/dev/null | wc -l | tr -d ' ')"
  ((n > keep_snapshots)) || return 0

  # shellcheck disable=SC2012
  ls -1d "$backup_root"/[0-9]*/ 2>/dev/null | sort |
    head -n "$((n - keep_snapshots))" |
    while read -r d; do rm -rf "$d"; done
  return 0
}

latest_snapshot() {
  # shellcheck disable=SC2012
  ls -1d "$backup_root"/[0-9]*/ 2>/dev/null | sort | tail -1
}

restore_snapshot() {
  local snap="${1%/}"

  # git-rev, not `-d`: the preflight directories passed the directory test,
  # have no git-rev at all, and the rollback printed "restoring" without
  # restoring anything.
  if [[ -z "$snap" || ! -f "$snap/git-rev" ]]; then
    ui_bad "$MSG_UPD_NO_SNAPSHOT"
    return 1
  fi

  ui_group "$MSG_UPD_GROUP_ROLLBACK"
  ui_run "$MSG_UPD_RESTORING" "$snap"

  local rev
  rev="$(cat "$snap/git-rev" 2>/dev/null)"

  if [[ -n "$rev" && "$rev" != none ]]; then
    # `reset --hard` wipes uncommitted changes to TRACKED files — including
    # ones that were already there before the update and that the script never
    # touched. The pull's --autostash does not protect you: it reapplies and
    # drops the stash, so not even an entry is left to recover from. A dirty
    # tree is the NORMAL state here (`p10k configure` rewrites the versioned
    # zsh/p10k.zsh), and on the offline path no pull happened at all: it would
    # destroy work for nothing.
    if git -C "$repo_dir" diff --quiet HEAD 2>/dev/null; then
      git -C "$repo_dir" reset --hard -q "$rev" && ui_ok "$MSG_UPD_REPO_RESET" "$rev"
    else
      ui_warn "$MSG_UPD_DIRTY"
      ui_note "$MSG_UPD_DIRTY_NOTE"
      ui_note "$MSG_UPD_DIRTY_CMD" "$repo_dir" "$repo_dir" "$rev"
    fi
  fi

  if [[ -f "$snap/machine.lua" ]]; then
    cp "$snap/machine.lua" "$repo_dir/machine.lua"
    ui_ok "$MSG_UPD_MACHINE_RESTORED"
  fi

  local f
  for f in lazy-lock.json lazyvim.json; do
    [[ -f "$snap/$f" ]] && cp "$snap/$f" "$repo_dir/nvim/$f" && ui_ok "$MSG_UPD_NVIM_RESTORED" "$f"
  done

  # Puts the Neovim plugins back on the SHAs of the restored lockfile.
  sync_nvim_plugins

  if [[ -f "$snap/mise-versions.txt" ]]; then
    msg_upd_versions_note "$snap/mise-versions.txt"
  fi
}

# ── Rollback mode ─────────────────────────────────────────────────────────

if [[ "${1:-}" == "--rollback" ]]; then
  restore_snapshot "${2:-$(latest_snapshot)}"
  echo
  exec bash "$repo_dir/scripts/check.sh"
fi

# ── Update ────────────────────────────────────────────────────────────────

# Portable timeout: macOS has no `timeout` (it comes from GNU coreutils).
#
# Never capture the output of a command wrapped here: the alarm only kills the
# direct child, and git leaves an orphaned `git-remote-https` holding the
# pipe, so the command substitution stays blocked long after the timeout.
tmo() { perl -e 'alarm shift @ARGV; exec @ARGV' "$@"; }

online=0
tmo 8 git -C "$repo_dir" ls-remote --exit-code origin HEAD >/dev/null 2>&1 && online=1

snapshot="$(take_snapshot)"
ui_group "$MSG_UPD_GROUP_SNAPSHOT"
ui_ok "$MSG_UPD_SNAPSHOT_AT" "${snapshot#"$repo_dir"/}"

before="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || echo none)"
after="$before"

# ── 1. Repository ─────────────────────────────────────────────────────────

if ((online)); then
  ui_group "$MSG_UPD_GROUP_REPO"
  ui_run "$MSG_UPD_PULL"
  # --autostash: immune to a dirty working tree, which is the number one cause
  # of an update script stalling halfway.
  git -C "$repo_dir" pull --rebase --autostash -q &&
    after="$(git -C "$repo_dir" rev-parse HEAD)"

  if [[ "$before" == "$after" ]]; then
    ui_skip "$MSG_UPD_UP_TO_DATE"
  else
    ui_ok "$MSG_UPD_PULLED" "$before" "$after"
  fi
else
  ui_group "$MSG_UPD_GROUP_REPO"
  ui_skip "$MSG_UPD_OFFLINE"
fi

changed() { ! git -C "$repo_dir" diff --quiet "$before" "$after" -- "$@" 2>/dev/null; }

# ── 2. Local: links and machine.lua. Always, and works offline. ───────────

ui_group "$MSG_UPD_GROUP_LINKS"

seed_machine_lua "$repo_dir"
link_all_configs "$repo_dir"

if ((online)); then
  # ── 3. Tools ────────────────────────────────────────────────────────────

  mise="$(mise_bin)"
  if [[ -n "$mise" ]]; then
    ui_group "$MSG_UPD_GROUP_TOOLS"
    ui_run "$MSG_UPD_MISE_UPGRADE"
    "$mise" upgrade
  fi

  if command -v brew >/dev/null 2>&1; then
    ui_run "$MSG_UPD_BREW"
    # HOMEBREW_NO_AUTO_UPDATE cuts an implicit `brew update` per invocation.
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1

    # `bundle check` is the gate: exit 0 = everything satisfied, skip the slow
    # install. --no-upgrade because `brew bundle install` upgrades by default,
    # and we do not want to update the whole world on every run.
    brew bundle check --file="$repo_dir/Brewfile" >/dev/null 2>&1 ||
      brew bundle install --file="$repo_dir/Brewfile" --no-upgrade

    # The nightly cask has `version :latest`, so brew cannot compare versions
    # and SKIPS it in a normal upgrade. Without --greedy-latest you sit months
    # behind thinking you are on the nightly.
    brew upgrade --cask wezterm@nightly --greedy-latest 2>/dev/null
  fi

  # ── 4. zsh and tmux. No gate: it is cheap and self-healing. ─────────────

  ui_group "$MSG_UPD_GROUP_PLUGINS"
  ui_run "$MSG_UPD_ZSH_REPOS"
  # No `omz update --unattended`: the flag was removed and the command returns
  # an error ("no longer supported, use the upgrade.sh script instead").
  sync_zsh_repos "$repo_dir" || ui_warn "$MSG_UPD_ZSH_FAILED"

  setup_tmux_plugins "$repo_dir"

  # ── 5. Neovim. With a gate: this is the expensive step. ─────────────────

  if changed nvim/; then
    sync_nvim_plugins
  else
    ui_skip "$MSG_UPD_NVIM_UNCHANGED"
  fi

  # ── 6. Zellij: nothing to do. ───────────────────────────────────────────
  # It watches the active config.kdl and reloads most options in real time.
  # The plugin cache is versioned per release, so upgrading the binary
  # invalidates it on its own.
fi

# ── 7. Verification, with automatic rollback ──────────────────────────────

echo
if bash "$repo_dir/scripts/check.sh"; then
  # Prune only after success: pruning first deleted this run's snapshot
  # exactly when the rollback was about to need it.
  prune_snapshots
  exit 0
fi

echo
printf '  %s%s✖  %s%s\n' "$UI_B" "$UI_VM" "$MSG_UPD_CHECK_FAILED" "$UI_R"
printf '  %s%s%s\n' "$UI_DIM" "$MSG_UPD_ROLLING_BACK" "$UI_R"

restore_snapshot "$snapshot"

ui_group "$MSG_UPD_GROUP_AFTER"

if bash "$repo_dir/scripts/check.sh"; then
  echo
  printf '  %s▲%s  %s%s%s\n' \
    "$UI_AM" "$UI_R" "$UI_B" "$MSG_UPD_RESTORED" "$UI_R"
  ui_note "$MSG_UPD_SNAPSHOT_KEPT" "${snapshot#"$repo_dir"/}"
  exit 1
fi

echo
printf '  %s✖%s  %s%s%s\n' \
  "$UI_VM" "$UI_R" "$UI_B" "$MSG_UPD_ROLLBACK_NOOP" "$UI_R"
ui_note "$MSG_UPD_SNAPSHOT_STILL" "${snapshot#"$repo_dir"/}"
exit 2
