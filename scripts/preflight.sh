#!/usr/bin/env bash
#
# Looks, BEFORE installing, for what already exists here and would get in the
# way.
#
#   bash scripts/preflight.sh           diagnose only (default)
#   bash scripts/preflight.sh --clean   resolve what it found, backup first
#   bash scripts/preflight.sh --clean --yes    without asking
#
# Why this is not an "uninstall everything and reinstall": what breaks is
# almost never the tool being installed. It is which copy wins on PATH and
# which config wins on precedence. Removing blindly takes away things you use
# today and fixes neither. So: detect the specific conflict, explain it, and
# remove only that — if you ask.
#
# Exits 0 when nothing is blocking, 1 when something is.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

do_clean=0
assume_yes=0

for arg in "$@"; do
  case "$arg" in
    --clean) do_clean=1 ;;
    --yes | -y) assume_yes=1 ;;
    *)
      printf '%s\n' "$(ui_fmt "$MSG_PRE_UNKNOWN_ARG" "$arg")" >&2
      exit 64
      ;;
  esac
done

backup_dir="$(backup_root)/preflight-$(date +%Y%m%d-%H%M%S)"
blocking=0
warnings=0
group_ok=0
declare -a fixes=()

((assume_yes)) && UI_YES=1

# Only what needs action shows up line by line; what is in order becomes a
# count at the end of the group. On a clean machine that is the difference
# between fifteen ✔ lines and one. TERMSTACK_VERBOSE=1 opens everything.
#
# All five take a catalog format plus its arguments and hand them straight to
# the ui_* helper: with a single argument the text is printed literally.
ok() {
  if [[ -n "${TERMSTACK_VERBOSE:-}" ]]; then
    ui_ok "$@"
  else
    group_ok=$((group_ok + 1))
  fi
}

warn() {
  ui_warn "$@"
  warnings=$((warnings + 1))
}

block() {
  ui_bad "$@"
  blocking=$((blocking + 1))
}

note() { ui_note "$@"; }

flush() {
  ((group_ok)) || return 0

  if ((group_ok == 1)); then
    ui_ok "$MSG_PRE_ONE_OK"
  else
    ui_ok "$MSG_PRE_N_OK" "$group_ok"
  fi

  group_ok=0
}

group() {
  flush
  ui_group "$@"
}

# Second run, invoked by setup AFTER the diagnosis already appeared on screen:
# it silences the scan and leaves only the summary, the plan and the Applying
# section. Without this the user answered "Resolve now? y" and saw the whole
# scan again, glued to the first one.
#
# warn/block keep counting: the exit code and the summary depend on them.
if [[ -n "${TERMSTACK_SCAN_QUIET:-}" ]]; then
  ok() { :; }
  warn() { warnings=$((warnings + 1)); }
  block() { blocking=$((blocking + 1)); }
  note() { :; }
  group() { :; }
  flush() { :; }
fi

# Records a fix for --clean mode as ACTION + TAB-separated arguments — never
# as a command string.
#
# The previous version stored the assembled command and ran `eval`. All it
# took was the repository sitting in a directory with an apostrophe — a
# machine named "O'Brien's MacBook" is common enough — for the command to
# break, and a path containing $(...) would have been executed. There is no
# plausible attacker in a dotfiles repository, but eval over a path is the
# kind of thing that only goes wrong on the day it does.
plan() {
  local IFS=$'\t'
  fixes+=("$*")
}

# Runs a recorded action. Every argument arrives whole, without going through
# any shell parsing layer.
apply_fix() {
  local action="$1"
  shift

  case "$action" in
    BACKUP) backup_path "$1" ;;
    MV) mv "$1" "$2" ;;
    RM) rm -f "$1" ;;
    RMDIR) rm -rf "$1" ;;
    BREW) brew uninstall --ignore-dependencies "$1" ;;
    BREW_CASK) brew uninstall --cask "$1" ;;
    *)
      echo "    unknown action: $action" >&2
      return 1
      ;;
  esac
}

# Only for display in the --clean plan.
describe_fix() {
  local action="$1"
  shift

  case "$action" in
    BACKUP) printf '%s\n' "$(ui_fmt "$MSG_PRE_FIX_BACKUP" "$1")" ;;
    MV) echo "mv \"$1\" \"$2\"" ;;
    RM) echo "rm \"$1\"" ;;
    RMDIR) echo "rm -rf \"$1\"" ;;
    BREW) echo "brew uninstall --ignore-dependencies $1" ;;
    BREW_CASK) echo "brew uninstall --cask $1" ;;
    *) echo "$action $*" ;;
  esac
}

# Name derived from the whole path, not from the basename: ~/.config/nvim and
# ~/.local/state/nvim fall into the SAME --clean and are both called "nvim" —
# the second cp -R would land INSIDE the first (~/nvim/nvim), scrambling the
# very copy that exists to undo the destructive step.
backup_path() {
  local src="$1" name
  name="${src#"$HOME"/}"
  name="${name//\//__}"
  # Without the leading dot: ".config__nvim" would vanish from an `ls` without
  # -a, and a backup nobody can see is a backup nobody finds under pressure.
  name="${name#.}"

  mkdir -p "$backup_dir"
  cp -R "$src" "$backup_dir/$name" 2>/dev/null &&
    note "$MSG_PRE_BACKED_UP" "${backup_dir/#$HOME/~}/$name"
}

# ── Tool installed by two managers ────────────────────────────────────────
# PATH decides which one runs, and it is almost never the newer one. That was
# the case for tmux on this machine: brew and mise both installed, brew
# winning.

group "$MSG_PRE_GROUP_DUPS"

brew_formulae=""
command -v brew >/dev/null 2>&1 && brew_formulae="$(brew list --formula 2>/dev/null)"

mise="$(mise_bin)"
mise_installed=""
[[ -n "$mise" ]] && mise_installed="$(ls "$HOME/.local/share/mise/installs" 2>/dev/null)"

# mise name -> binary name
tool_binary() {
  case "$1" in
    neovim) echo nvim ;;
    ripgrep) echo rg ;;
    *) echo "$1" ;;
  esac
}

dup_found=0

# The list comes from the versioned mise/config.toml — the same source the
# bootstrap uses.
mise_tools="$(awk '/^\[tools\]/{f=1; next} /^\[/{f=0} f && /=/{sub(/[[:space:]]*=.*/, ""); print}' \
  "$repo_dir/mise/config.toml" 2>/dev/null)"

for tool in $mise_tools; do
  grep -qx "$tool" <<<"$mise_installed" || continue
  grep -qx "$tool" <<<"$brew_formulae" || continue

  dup_found=1
  bin="$(tool_binary "$tool")"
  winner="$(command -v "$bin" 2>/dev/null || echo '(not on PATH)')"

  warn "$MSG_PRE_DUP_TOOL" "$tool"
  note "$MSG_PRE_DUP_WINNER" "$winner"
  note "$MSG_PRE_DUP_STALE"
  plan BREW "$tool"
done

((dup_found)) || ok "$MSG_PRE_NO_DUPS"

# ── Stable WezTerm alongside the nightly ──────────────────────────────────
# Both casks install the same /Applications/WezTerm.app.

if [[ -n "$brew_formulae" ]] && command -v brew >/dev/null 2>&1; then
  casks="$(brew list --cask 2>/dev/null)"

  if grep -qx 'wezterm' <<<"$casks" && grep -qx 'wezterm@nightly' <<<"$casks"; then
    block "$MSG_PRE_CASK_BOTH"
    note "$MSG_PRE_CASK_BOTH_NOTE"
    plan BREW_CASK wezterm
  elif grep -qx 'wezterm' <<<"$casks"; then
    warn "$MSG_PRE_CASK_STABLE"
    note "$MSG_PRE_CASK_STABLE_NOTE"
    plan BREW_CASK wezterm
  fi
fi

# ── Configs competing for precedence ──────────────────────────────────────

group "$MSG_PRE_GROUP_CONFIG"

# dest, source in the repo, old config that loses precedence
check_config() {
  local dest="$1" src="$2" legacy="${3:-}" label="${4:-}"
  local name
  name="${label:-$(basename "$dest")}"

  # The README says to clone into ~/.config/wezterm, and then `dest` AND `src`
  # are the repository itself. Without this early return, --clean plans an `mv`
  # of the repo to wezterm.bak: setup.sh keeps calling the bootstrap at a path
  # that just vanished and the whole install dies on the README's first
  # command.
  if [[ -e "$dest" && "$dest" -ef "$src" ]]; then
    ok "$MSG_PRE_CFG_IS_REPO" "$name"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      ok "$MSG_PRE_CFG_LINKED" "$name"
    else
      block "$MSG_PRE_CFG_ELSEWHERE" "$name" "$(readlink "$dest")"
      plan RM "$dest"
    fi
  elif [[ -e "$dest" ]]; then
    block "$MSG_PRE_CFG_EXISTS" "$name"
    plan BACKUP "$dest"
    plan MV "$dest" "$dest.bak"
  else
    ok "$MSG_PRE_CFG_FREE" "$name"
  fi

  # The tmux case: ~/.config/tmux/tmux.conf takes precedence over
  # ~/.tmux.conf, so creating the link leaves the old config alive on disk but
  # inert.
  if [[ -n "$legacy" && -f "$legacy" ]]; then
    block "$MSG_PRE_CFG_LEGACY" "$(basename "$legacy")" "$name"
    note "$MSG_PRE_CFG_LEGACY_NOTE"
    plan BACKUP "$legacy"
    plan MV "$legacy" "$legacy.bak"
  fi
}

# The mise tool list is versioned in the repository. Without the link, each
# machine keeps its own list and `git pull` brings no new tool.
check_config "$HOME/.config/mise/config.toml" "$repo_dir/mise/config.toml" "" "mise/config.toml"
check_config "$HOME/.config/wezterm" "$repo_dir"
check_config "$HOME/.config/zellij" "$repo_dir/zellij"
check_config "$HOME/.config/nvim" "$repo_dir/nvim"
check_config "$HOME/.config/tmux" "$repo_dir/tmux" "$HOME/.tmux.conf"

# Zellij walks [~/.config/zellij, ProjectDirs, /etc/zellij] and uses the FIRST
# that exists. With both present, the Library one is ignored silently — the
# classic "I edited the config and nothing changed".
zellij_legacy="$HOME/Library/Application Support/org.Zellij-Contributors.zellij"
if [[ -d "$zellij_legacy" ]]; then
  warn "$MSG_PRE_ZELLIJ_LEGACY"
  note "$MSG_PRE_ZELLIJ_LEGACY_NOTE"
  plan BACKUP "$zellij_legacy"
  plan RMDIR "$zellij_legacy"
fi

# ── State from another Neovim distribution ────────────────────────────────
# LazyVim on top of AstroNvim/NvChad/LunarVim state produces obscure plugin
# errors. Only a problem when ~/.config/nvim is NOT ours.

group "$MSG_PRE_GROUP_STALE"

nvim_state_stale=0
if [[ "$(readlink "$HOME/.config/nvim" 2>/dev/null)" != "$repo_dir/nvim" ]]; then
  for d in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [[ -d "$d" ]] || continue
    nvim_state_stale=1
    warn "$MSG_PRE_NVIM_STATE" "${d#"$HOME"/}" "$(du -sh "$d" 2>/dev/null | cut -f1 | tr -d ' ')"
    # share/ (lazy, mason) and cache/ regenerate on their own next nvim run.
    # state/ does not: it is shada, persistent undo and swap — marks, history
    # and a session that died unsaved. It is the only one worth copying.
    [[ "$d" == */state/nvim ]] && plan BACKUP "$d"
    plan RMDIR "$d"
  done
fi
((nvim_state_stale)) || ok "$MSG_PRE_NVIM_STATE_NONE"

# TPM plugins at the old path. They only become litter once ~/.config/tmux
# takes over — before that they are the installation in use.
if [[ -d "$HOME/.tmux/plugins" ]] &&
  [[ "$(readlink "$HOME/.config/tmux" 2>/dev/null)" == "$repo_dir/tmux" ]]; then
  warn "$MSG_PRE_TMUX_OLD" "$(du -sh "$HOME/.tmux/plugins" 2>/dev/null | cut -f1)"
  note "$MSG_PRE_TMUX_OLD_NOTE"
  plan RMDIR "$HOME/.tmux/plugins"
elif [[ -d "$HOME/.tmux/plugins" ]]; then
  ok "$MSG_PRE_TMUX_IN_USE" "$HOME/.tmux/plugins"
fi

# ── Shell ────────────────────────────────────────────────────────────────

group "$MSG_PRE_GROUP_SHELL"

zshrc="$HOME/.zshrc"

# ZDOTDIR changes where zsh reads .zshrc from. The bootstrap writes into $HOME
# and the config never loads — with no error at all, the worst kind of
# failure.
if [[ -n "${ZDOTDIR:-}" && "$ZDOTDIR" != "$HOME" ]]; then
  block "$MSG_PRE_ZDOTDIR" "$ZDOTDIR"
  note "$MSG_PRE_ZDOTDIR_NOTE"
fi

if [[ -f "$zshrc" ]]; then
  # oh-my-zsh existing is NOT a conflict — it is the design of this config.
  # The conflict is the rc loading its OWN oh-my-zsh/p10k outside the marked
  # block: that would be two compinit calls and two instant-prompt blocks.
  #
  # It has to look at the rc WITH THE MARKED BLOCK REMOVED. Searching the
  # whole file for 'termstack' does not work: as soon as the bootstrap
  # writes the block (even the block that only sets EDITOR), the test starts
  # believing the omz is ours and the block disappears on exactly the machine
  # that needs it.
  # Both markers: the project used to be called wezterm-config, and an rc
  # written by that version still carries the old one. Missing it here would
  # make preflight read the user's own oh-my-zsh as ours.
  rc_outside_block="$(awk '
    /^# >>> (termstack|wezterm-config) >>>/ { skip = 1 }
    !skip { print }
    /^# <<< (termstack|wezterm-config) <<</ { skip = 0 }
  ' "$zshrc" 2>/dev/null)"

  # Comments stripped for the same reason as in _common.sh: a migrated rc that
  # documents what the source line replaced is not an rc with its own framework.
  if awk '{ sub(/#.*/, ""); print }' <<<"$rc_outside_block" |
    grep -qE 'oh-my-zsh\.sh|p10k-instant-prompt|antigen|zinit|zplug|prezto'; then
    block "$MSG_PRE_OWN_OMZ" "$HOME/.zshrc"
    note "$MSG_PRE_OWN_OMZ_NOTE1"
    note "$MSG_PRE_OWN_OMZ_NOTE2"
    plan BACKUP "$zshrc"
  fi

  # Two prompts fighting over PROMPT.
  if grep -qE 'starship init|STARSHIP_CONFIG' "$zshrc" 2>/dev/null; then
    block "$MSG_PRE_STARSHIP"
  fi

  # After the migration the repository wins, and this file drops out of the
  # flow.
  if [[ -f "$HOME/.p10k.zsh" ]]; then
    warn "$MSG_PRE_P10K_HOME" "$HOME/.p10k.zsh"
    note "$MSG_PRE_P10K_HOME_NOTE"
  fi

  # Two compinit calls cost twice as much and apply the zstyles in the wrong
  # order. No `|| echo 0`: grep -c already prints the number, and when it is
  # zero it exits 1 — the fallback would add a second zero and break the
  # arithmetic.
  compinit_calls="$(grep -cE '^[[:space:]]*compinit' "$zshrc" 2>/dev/null)"
  ((compinit_calls > 0)) && warn "$MSG_PRE_COMPINIT" "$compinit_calls"

  # nvm is by far the biggest startup cost that shows up in these rc files —
  # and with mise installed it is two Node managers fighting over PATH.
  if grep -q 'nvm\.sh' "$zshrc" 2>/dev/null && [[ -n "$mise" ]]; then
    warn "$MSG_PRE_NVM"
    note "$MSG_PRE_NVM_NOTE"
  fi
else
  ok "$MSG_PRE_NO_ZSHRC"
fi

# The p10k wizard does NOT detect fonts: it records MODE from the answers you
# gave to its glyph questions. MODE=powerline with the Nerd Font installed
# means icons stuck on the ugly fallback (∅ for the lock, ≡ for jobs).
if p10k_needs_configure "$repo_dir"; then
  warn "$MSG_PRE_P10K_MODE" "$(p10k_mode "$repo_dir")"
  note "$MSG_PRE_P10K_MODE_NOTE"
fi

# An fpath with a world-writable directory stalls the first shell of the day
# asking "Ignore insecure directories?".
if command -v zsh >/dev/null 2>&1; then
  if zsh -c 'autoload -Uz compaudit; compaudit' >/dev/null 2>&1; then
    ok "$MSG_PRE_FPATH_OK"
  else
    warn "$MSG_PRE_COMPAUDIT"
    note "$MSG_PRE_COMPAUDIT_NOTE"
  fi
fi

# ── mise not activated in the shell ───────────────────────────────────────

group "$MSG_PRE_GROUP_ENV"

if [[ -z "$mise" ]]; then
  ok "$MSG_PRE_NO_MISE"
elif command -v nvim >/dev/null 2>&1 || command -v zellij >/dev/null 2>&1; then
  ok "$MSG_PRE_MISE_ON_PATH"
else
  warn "$MSG_PRE_MISE_INACTIVE"
  note "$MSG_PRE_MISE_INACTIVE_NOTE"
fi

# ── Result ────────────────────────────────────────────────────────────────

# From here on the note speaks again even in the quiet run: it is what prints
# the "backed up to ..." line during the apply.
if [[ -n "${TERMSTACK_SCAN_QUIET:-}" ]]; then
  note() { ui_note "$@"; }
fi

flush
echo

if ((blocking == 0 && warnings == 0)); then
  printf '  %s✔%s  %s%s%s\n' \
    "$UI_VD" "$UI_R" "$UI_B" "$MSG_PRE_ALL_CLEAR" "$UI_R"
  exit 0
fi

plural() { (($1 == 1)) && echo "$2" || echo "$3"; }

printf '  %s%s✖ %d %s%s   %s%s▲ %d %s%s\n' \
  "$UI_B" "$UI_VM" "$blocking" "$(plural "$blocking" "$MSG_PRE_BLOCKER" "$MSG_PRE_BLOCKERS")" "$UI_R" \
  "$UI_B" "$UI_AM" "$warnings" "$(plural "$warnings" "$MSG_PRE_WARNING" "$MSG_PRE_WARNINGS")" "$UI_R"

# Only what --clean would actually execute. BACKUP does not count: it always
# accompanies an MV or RM, never shows up alone, and a group with a title and
# nothing under it is worse than no group at all.
declare -a shown=()
for f in "${fixes[@]:-}"; do
  [[ -n "$f" ]] || continue
  IFS=$'\t' read -r -a parts <<<"$f"
  [[ "${parts[0]}" == BACKUP ]] || shown+=("$(describe_fix "${parts[@]}")")
done

if ((${#shown[@]} == 0)); then
  exit $((blocking > 0 ? 1 : 0))
fi

ui_group "$MSG_PRE_GROUP_PLAN"
for f in "${shown[@]}"; do
  ui_run "$f"
done

if ((!do_clean)); then
  echo
  ui_note "$MSG_PRE_UNAPPLIED"
  ui_note "$MSG_PRE_UNAPPLIED_NOTE"
  exit $((blocking > 0 ? 1 : 0))
fi

if ! ui_ask "$MSG_PRE_ASK_APPLY"; then
  echo
  ui_skip "$MSG_PRE_CANCELLED"
  exit $((blocking > 0 ? 1 : 0))
fi

ui_group "$MSG_PRE_GROUP_APPLYING"

for f in "${fixes[@]}"; do
  # Rebuilds the arguments by TAB. No eval, no re-parsing: a path with a
  # space, a quote or a dollar sign reaches `mv` and `rm` whole.
  IFS=$'\t' read -r -a parts <<<"$f"

  [[ "${parts[0]}" == BACKUP ]] || ui_run "$(describe_fix "${parts[@]}")"
  apply_fix "${parts[@]}" || ui_bad "$MSG_PRE_FIX_FAILED"
done

echo
printf '  %s✔%s  %s%s%s\n' \
  "$UI_VD" "$UI_R" "$UI_B" "$MSG_PRE_DONE" "$UI_R"
exit 0
