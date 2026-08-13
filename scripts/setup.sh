#!/usr/bin/env bash
#
# Entry point. This is how you install — the bootstrap scripts are called by
# it, not directly.
#
#   bash scripts/setup.sh            diagnose, ask, install, verify
#   bash scripts/setup.sh --clean    resolve the conflicts it finds
#   bash scripts/setup.sh --yes      never ask anything (automation)
#
# After installing WezTerm it relaunches itself INSIDE it and carries on. That
# is not decoration: `p10k configure` and checking the glyphs are only
# meaningful in a terminal that already has the Nerd Font active.
#
# Nothing is uninstalled without --clean, and not even with it without a
# backup first.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

do_clean=0
assume_yes=0
resumed=0

usage() {
  msg_setup_usage
}

for arg in "$@"; do
  case "$arg" in
    --clean) do_clean=1 ;;
    --yes | -y) assume_yes=1 ;;
    --resumed) resumed=1 ;; # internal: we already went through the handoff
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

case "$(uname -s)" in
  Darwin) bootstrap="bootstrap-macos.sh" ;;
  Linux) bootstrap="bootstrap-linux.sh" ;;
  *)
    printf '%s\n' "$(ui_fmt "$MSG_SETUP_UNSUPPORTED" "$(uname -s)")" >&2
    printf '%s\n' "$MSG_SETUP_WINDOWS" >&2
    exit 1
    ;;
esac

# ── Appearance ────────────────────────────────────────────────────────────
# The helpers (ui_*) live in _common.sh: the same ones preflight, check and
# the bootstrap use, so the whole install reads as a single program.

UI_STEPS=5
((assume_yes)) && UI_YES=1

in_wezterm() {
  [[ -n "${WEZTERM_PANE:-}" || "${TERM_PROGRAM:-}" == WezTerm ]]
}

signal_origin() {
  local flag
  flag="$(handoff_flag)"
  mkdir -p "$(dirname "$flag")"
  : >"$flag"
}

# Signals as well when this window dies halfway — script error, Ctrl+C, the
# user closing the window. Without this, any of those leaves the originating
# terminal waiting the full 30 minutes for a signal that is never coming.
#
# Does not cover the `exec` at the end: exec replaces the process image and
# takes the trap with it. There the signal is written by hand, before.
((resumed)) && trap signal_origin EXIT

# Ctrl+C halfway leaves nothing broken that another run will not fix —
# everything here is idempotent. Saying so at interrupt time is what keeps the
# user from thinking they broke the machine.
# shellcheck disable=SC2329  # invoked by the INT trap right below
on_interrupt() {
  printf '\n\n  %s▲%s  %s%s%s\n\n' \
    "$UI_AM" "$UI_R" "$UI_B" "$MSG_SETUP_INTERRUPTED" "$UI_R"
  exit 130
}
trap on_interrupt INT

# The step's verdict. Group indentation, not item: it is the verdict of the
# whole step, not one more line of what the sub-script just printed.
#
# Text comes from the catalog, so it takes a format plus arguments, exactly
# like the ui_* helpers: with a single argument it is printed literally.
res() {
  local color="$1" symbol="$2"
  shift 2
  printf '\n  %s%s%s  %s%s%s\n' "$color" "$symbol" "$UI_R" "$UI_B" "$(ui_fmt "$@")" "$UI_R"
}

res_ok() { res "$UI_VD" ✔ "$@"; }
res_warn() { res "$UI_AM" ▲ "$@"; }
res_bad() { res "$UI_VM" ✖ "$@"; }

ui_banner "termstack" "WezTerm · Zellij · LazyVim · tmux"

if ((resumed)); then
  ui_skip "$MSG_SETUP_RESUMING"
fi

# ── 1. Diagnose ───────────────────────────────────────────────────────────

if ((resumed)); then
  UI_STEP=2 # 1 and 2 already ran in the previous window
else
  ui_step "$MSG_SETUP_STEP_DIAGNOSE" "$MSG_SETUP_STEP_DIAGNOSE_DESC"

  bash "$repo_dir/scripts/preflight.sh"
  preflight_rc=$?

  if ((preflight_rc == 0)); then
    res_ok "$MSG_SETUP_NO_CONFLICTS"
  else
    res_warn "$MSG_SETUP_CONFLICTS"

    # SCAN_QUIET: the diagnosis just appeared above — the run that applies
    # shows only the plan and the Applying section, not the scan again.
    if ((do_clean)); then
      ui_note "$MSG_SETUP_CLEAN_NOW"
      TERMSTACK_SCAN_QUIET=1 bash "$repo_dir/scripts/preflight.sh" --clean --yes

    elif ((assume_yes)); then
      # --yes means "do not ask me", not "yes to everything". Moving the
      # user's existing config is destructive enough to require an explicit
      # --clean.
      ui_note "$MSG_SETUP_YES_NO_CLEAN"

    elif ui_ask "$MSG_SETUP_ASK_RESOLVE"; then
      TERMSTACK_SCAN_QUIET=1 bash "$repo_dir/scripts/preflight.sh" --clean --yes

    elif ! ui_ask "$MSG_SETUP_ASK_CARRY_ON"; then
      res_bad "$MSG_SETUP_CANCELLED"
      ui_note "$MSG_SETUP_CANCELLED_NOTE"
      exit 0
    fi
  fi

  # ── 2. Install ──────────────────────────────────────────────────────────

  # With no terminal and no --yes nobody can confirm anything. Installing
  # WezTerm, oh-my-zsh and ten CLI tools because someone redirected the output
  # to a file is not the script's call to make.
  if ! ((assume_yes)) && ! [[ -t 0 ]]; then
    res_bad "$MSG_SETUP_NO_TTY"
    ui_note "$MSG_SETUP_NO_TTY_NOTE"
    exit 0
  fi

  ui_step "$MSG_SETUP_STEP_INSTALL" "$MSG_SETUP_STEP_INSTALL_DESC"

  TERMSTACK_FROM_SETUP=1 bash "$repo_dir/scripts/$bootstrap"
  res_ok "$MSG_SETUP_INSTALLED"
fi

# ── 3. Handoff to WezTerm ─────────────────────────────────────────────────

ui_step "$MSG_SETUP_STEP_TERMINAL" "$MSG_SETUP_STEP_TERMINAL_DESC"

wezterm_bin="$(tool_bin wezterm)"
[[ -z "$wezterm_bin" && -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]] &&
  wezterm_bin=/Applications/WezTerm.app/Contents/MacOS/wezterm

if in_wezterm; then
  res_ok "$MSG_SETUP_IN_WEZTERM"

elif ((resumed)); then
  # We were relaunched but detection failed. Do not try again: an infinite
  # loop of windows is worse than a warning.
  ui_warn "$MSG_SETUP_UNCONFIRMED"
  ui_note "$MSG_SETUP_UNCONFIRMED_NOTE"

elif [[ -z "$wezterm_bin" ]]; then
  ui_warn "$MSG_SETUP_NO_WEZTERM"
  ui_note "$MSG_SETUP_NO_WEZTERM_NOTE"

elif ! [[ -t 1 ]]; then
  ui_skip "$MSG_SETUP_NO_TTY_HERE"

else
  flag="$(handoff_flag)"
  mkdir -p "$(dirname "$flag")"
  rm -f "$flag"

  ui_run "$MSG_SETUP_OPENING"

  # In the background on purpose. `wezterm start` stays bound to the lifetime
  # of the window it opened, and the new window ends in `exec $SHELL` — that
  # is, never. In the foreground this terminal hung forever, with a half
  # finished install on screen and no prompt back.
  # The exit code goes to a file because the command is backgrounded and
  # `wait` takes no timeout. It cannot be swapped for "is the process still
  # alive?": when a WezTerm GUI is already running, `start` hands the window
  # to THAT process and exits 0 immediately — alive-or-dead would read that as
  # a failure and tell the user to install by hand, precisely for those who
  # already had WezTerm open.
  gui_rc="$(mktemp)"
  {
    "$wezterm_bin" start -- bash "$repo_dir/scripts/setup.sh" --resumed 2>/dev/null
    echo $? >"$gui_rc"
  } &
  disown 2>/dev/null || true

  # The window takes a moment to exist; only after that can we tell.
  sleep 3

  if [[ -s "$gui_rc" ]] && [[ "$(cat "$gui_rc")" != 0 ]]; then
    rm -f "$gui_rc"
    res_warn "$MSG_SETUP_GUI_FAILED"
    ui_note "$MSG_SETUP_GUI_FAILED_NOTE" "$repo_dir"
    exit 0
  fi

  ui_ok "$MSG_SETUP_HANDED_OFF"
  ui_note "$MSG_SETUP_HANDED_OFF_NOTE"

  # Waits for the signal from the other side. A 30 min ceiling so it does not
  # hang when the window is closed halfway: no signal comes then, and nobody
  # is going to tell us.
  waited=0
  while [[ ! -e "$flag" ]] && ((waited < 1800)); do
    sleep 2
    waited=$((waited + 2))
  done

  rm -f "$gui_rc"

  if [[ -e "$flag" ]]; then
    rm -f "$flag"
    res_ok "$MSG_SETUP_HANDOFF_DONE"
  else
    res_warn "$MSG_SETUP_HANDOFF_TIMEOUT"
    ui_note "$MSG_SETUP_HANDOFF_TIMEOUT_NOTE"
  fi

  exit 0
fi

# ── 4. Prompt ─────────────────────────────────────────────────────────────

ui_step "$MSG_SETUP_STEP_PROMPT" "$MSG_SETUP_STEP_PROMPT_DESC"

if ! p10k_needs_configure "$repo_dir"; then
  res_ok "$MSG_SETUP_P10K_OK" "$(p10k_mode "$repo_dir")"
else
  ui_warn "$MSG_SETUP_P10K_MISMATCH" "$(p10k_mode "$repo_dir")"
  msg_setup_p10k_why

  if ui_ask "$MSG_SETUP_ASK_P10K"; then
    echo
    run_p10k_configure "$repo_dir"
    res_ok "$MSG_SETUP_P10K_DONE"
  else
    res_warn "$MSG_SETUP_P10K_SKIPPED"
  fi
fi

# ── 5. Verify ─────────────────────────────────────────────────────────────

ui_step "$MSG_SETUP_STEP_VERIFY" "$MSG_SETUP_STEP_VERIFY_DESC"

bash "$repo_dir/scripts/check.sh"
check_rc=$?

if ((check_rc == 0)); then
  # Only when it actually took time: "0m12s" on a run where everything was
  # already installed is noise.
  if ((SECONDS >= 60)); then
    res_ok "$MSG_SETUP_DONE_IN" "$((SECONDS / 60))" "$((SECONDS % 60))"
  fi

  bash "$repo_dir/scripts/cheatsheet.sh"

  ui_group "$MSG_SETUP_NEXT_STEPS"
  # shellcheck disable=SC2016  # $SHELL is literal, for the user to type
  printf '    %s1%s  %sexec $SHELL%s   %s\n' \
    "$UI_AZ" "$UI_R" "$UI_B" "$UI_R" "$MSG_SETUP_NEXT_SHELL"
  printf '    %s2%s  %szellij%s        %s\n' \
    "$UI_AZ" "$UI_R" "$UI_B" "$UI_R" "$MSG_SETUP_NEXT_ZELLIJ"
  printf '    %s3%s  %snvim%s          %s\n\n' \
    "$UI_AZ" "$UI_R" "$UI_B" "$UI_R" "$MSG_SETUP_NEXT_NVIM"
else
  res_bad "$MSG_SETUP_CHECK_FAILED"
  ui_note "$MSG_SETUP_CHECK_FAILED_NOTE1"
  ui_note "$MSG_SETUP_CHECK_FAILED_NOTE2"
  echo
fi

# Releases the originating terminal, which is parked waiting for this signal.
# Before the `exec` below, mandatorily: exec replaces the process image and
# takes the trap with it, so from there on nobody is left to write anything.
((resumed)) && signal_origin

# Relaunched in a new window: land in an interactive shell instead of closing
# the window in the user's face — and it is already the new shell, with the
# environment applied.
if ((resumed)) && [[ -t 0 ]]; then
  printf '  %s%s%s\n\n' "$UI_DIM" "$MSG_SETUP_NEW_SHELL" "$UI_R"
  exec "${SHELL:-/bin/zsh}" -l
fi

exit "$check_rc"
