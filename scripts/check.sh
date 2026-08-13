#!/usr/bin/env bash
#
# Verifies that the configs really load, before pushing to the other
# machines.
#
# Why the exit code is not enough: `wezterm show-keys` exits 0 even with a
# broken config — it silently falls back to the default config, writing
# nothing to stderr. The reliable signal is the `Leader:` line disappearing
# from the output, since this repository's config always defines a leader.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

failures=0
group_ok=0

# Thirty-five ✔ lines in a row do not get read — the eye slides over them and
# the ✖ in the middle goes with it. So only what needs action shows up right
# away; what passed becomes a count at the end of the group.
# TERMSTACK_VERBOSE=1 opens everything, for when the question is "was
# this even verified?".
#
# The three take a catalog format plus its arguments and hand them straight to
# the ui_* helper: with a single argument the text is printed literally.
ok() {
  if [[ -n "${TERMSTACK_VERBOSE:-}" ]]; then
    ui_ok "$@"
  else
    group_ok=$((group_ok + 1))
  fi
}

bad() {
  ui_bad "$@"
  failures=$((failures + 1))
}

skip() { ui_skip "$@"; }

# Closes the open group before opening the next one.
flush() {
  ((group_ok)) || return 0

  if ((group_ok == 1)); then
    ui_ok "$MSG_CHECK_ONE_OK"
  else
    ui_ok "$MSG_CHECK_N_OK" "$group_ok"
  fi

  group_ok=0
}

group() {
  flush
  ui_group "$@"
}

# Temporary files with unpredictable names. A fixed name in /tmp is writable
# by any user on the machine: on a shared host someone can pre-create the path
# as a symlink and make check write where it should not.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

find_wezterm() {
  local bin
  bin="$(tool_bin wezterm)"

  if [[ -n "$bin" ]]; then
    echo "$bin"
  elif [[ -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]]; then
    echo /Applications/WezTerm.app/Contents/MacOS/wezterm
  elif [[ -x "$HOME/Applications/WezTerm.app/Contents/MacOS/wezterm" ]]; then
    echo "$HOME/Applications/WezTerm.app/Contents/MacOS/wezterm"
  fi
}

group "$MSG_CHECK_GROUP_MACHINE"

if [[ "$(uname -s)" == "Darwin" ]]; then
  # Informational, not a failure. It matters when something below fails with
  # no explanation: on a managed Mac, company execution policy is the first
  # suspect — a stricter Gatekeeper, a security agent blocking a binary in
  # ~/.local/bin, a TLS-inspecting proxy breaking downloads.
  if tmo 15 profiles status -type enrollment 2>/dev/null | grep -q 'MDM enrollment: Yes'; then
    skip "$MSG_CHECK_MDM"
  else
    ok "$MSG_CHECK_NO_MDM"
  fi
fi

if [[ -n "$(mise_bin)" ]]; then
  ok "$MSG_CHECK_MISE_PRESENT" \
    "$(tool_bin nvim >/dev/null && echo "$MSG_CHECK_TOOLS_RESOLVE" || echo "$MSG_CHECK_NO_TOOLS")"
else
  skip "$MSG_CHECK_NO_MISE"
fi

group "$MSG_CHECK_GROUP_WEZTERM"

wezterm_bin="$(find_wezterm)"

if [[ -z "$wezterm_bin" ]]; then
  skip "$MSG_CHECK_WEZTERM_MISSING"
else
  # With a timeout and output to a file: a quarantined binary on macOS does
  # not fail, it hangs in dyld forever. Without this, check freezes.
  tmo 20 "$wezterm_bin" --config-file "$repo_dir/wezterm.lua" show-keys \
    >"$tmpdir/wezterm.out" 2>/dev/null
  wezterm_rc=$?
  keys="$(cat "$tmpdir/wezterm.out")"

  if ((wezterm_rc == 142)); then
    bad "$MSG_CHECK_WEZTERM_HUNG"
    first_launch_hint "/Applications/WezTerm.app"
    ui_note "$MSG_CHECK_WEZTERM_HUNG_NOTE1"
    ui_note "$MSG_CHECK_WEZTERM_HUNG_NOTE2"
  elif grep -q '^Leader:' <<<"$keys"; then
    ok "$MSG_CHECK_WEZTERM_LOADS"
  else
    bad "$MSG_CHECK_WEZTERM_FALLBACK"
    ui_note "$MSG_CHECK_WEZTERM_FALLBACK_NOTE" "$wezterm_bin" "$repo_dir"
  fi

  # The bindings have to be checked WITH the LEADER prefix: WezTerm's default
  # config also has SplitHorizontal and friends, so searching for the action
  # alone would pass even with the config fallen back to the default.
  for binding in SplitHorizontal SplitVertical ActivateCopyMode TogglePaneZoomState; do
    if grep -E "LEADER.*$binding" <<<"$keys" >/dev/null; then
      ok "$MSG_CHECK_BINDING_OK" "$binding"
    else
      bad "$MSG_CHECK_BINDING_MISSING" "$binding"
    fi
  done
fi

group "$MSG_CHECK_GROUP_TMUX"

tmux_bin="$(tool_bin tmux)"

if [[ -z "$tmux_bin" ]]; then
  skip "$MSG_CHECK_TMUX_MISSING"
else
  # Throwaway HOME and socket: the config resolves plugins through
  # $HOME/.config/tmux/plugins, and this test must not touch the user's server
  # or config.
  # Inside $tmpdir so the EXIT trap takes it along: with its own mktemp -d, a
  # Ctrl+C in the middle of the tmux block left the directory behind.
  fake_home="$(mktemp -d "$tmpdir/home.XXXXXX")"
  mkdir -p "$fake_home/.config"
  ln -s "$repo_dir/tmux" "$fake_home/.config/tmux"

  socket=termstack-check
  "$tmux_bin" -L "$socket" kill-server 2>/dev/null

  # The tmux directory has to be on the server's PATH: the TPM and plugin
  # scripts call `tmux` BY NAME. When tmux comes from mise and the shell
  # running this check never went through `mise activate`, they fail silently
  # and the bar comes up with no theme — no error on stderr at all.
  #
  # new-session and not start-server: a server with no session dies instantly,
  # and every following command would start a new one without our config.
  conf_err="$(HOME="$fake_home" PATH="$(dirname "$tmux_bin"):$PATH" \
    "$tmux_bin" -L "$socket" \
    -f "$repo_dir/tmux/tmux.conf" new-session -d -s check 2>&1)"

  if [[ -n "$conf_err" ]]; then
    bad "$MSG_CHECK_TMUX_CONF_ERR" "$conf_err"
  else
    ok "$MSG_CHECK_TMUX_CONF_OK"
  fi

  prefix="$("$tmux_bin" -L "$socket" show-options -gv prefix 2>/dev/null)"

  if [[ "$prefix" == "C-Space" ]]; then
    ok "$MSG_CHECK_TMUX_PREFIX_OK"
  else
    bad "$MSG_CHECK_TMUX_PREFIX_BAD" "$prefix"
  fi

  # catppuccin exports the flavor colors as @thm_*. If they exist, the plugin
  # loaded.
  if [[ -n "$("$tmux_bin" -L "$socket" show-options -gv @thm_green 2>/dev/null)" ]]; then
    ok "$MSG_CHECK_TMUX_THEME_OK"
  else
    bad "$MSG_CHECK_TMUX_THEME_BAD"
  fi

  status_right="$("$tmux_bin" -L "$socket" show-options -gv status-right 2>/dev/null)"

  # cpu/ram/battery enter the bar through `set -agF`, which expands the format
  # right away: the text becomes `#{cpu_percentage}` and the plugins replace it
  # with a script call. A leftover placeholder means the plugin never ran.
  for widget in cpu_percentage ram_percentage battery_percentage; do
    if [[ "$status_right" == *"#{$widget}"* ]]; then
      bad "$MSG_CHECK_WIDGET_RAW" "$widget"
    elif [[ "$status_right" == *"$widget.sh"* ]]; then
      ok "$MSG_CHECK_WIDGET_OK" "$widget"
    else
      bad "$MSG_CHECK_WIDGET_MISSING" "$widget"
    fi
  done

  windows="$("$tmux_bin" -L "$socket" list-windows -t check -F '#{window_index}' 2>/dev/null | head -1)"

  if [[ "$windows" == "1" ]]; then
    ok "$MSG_CHECK_TMUX_BASE_OK"
  else
    bad "$MSG_CHECK_TMUX_BASE_BAD" "$windows"
  fi

  "$tmux_bin" -L "$socket" kill-server 2>/dev/null
  rm -rf "$fake_home"
fi

group "$MSG_CHECK_GROUP_ZELLIJ"

zellij_bin="$(tool_bin zellij)"

if [[ -z "$zellij_bin" ]]; then
  skip "$MSG_CHECK_ZELLIJ_MISSING"
else
  # Invalid config: error on stderr (with a KDL span), exit 1.
  # Valid config: lists the directories on stdout, exit 0.
  if setup_out="$("$zellij_bin" setup --check 2>"$tmpdir/zellij.err")"; then
    ok "$MSG_CHECK_ZELLIJ_KDL_OK"
  else
    bad "$MSG_CHECK_ZELLIJ_KDL_BAD" "$(head -3 "$tmpdir/zellij.err")"
    setup_out=""
  fi

  # The macOS trap: Zellij looks for ~/.config/zellij and, if it is missing,
  # falls back to ~/Library/Application Support, ignoring the repository
  # silently.
  if [[ -n "$setup_out" ]]; then
    if grep -q 'CONFIG DIR.*\.config/zellij' <<<"$setup_out"; then
      ok "$MSG_CHECK_ZELLIJ_DIR_OK"
    else
      bad "$MSG_CHECK_ZELLIJ_DIR_BAD" "$(grep 'CONFIG DIR' <<<"$setup_out" | head -1)"
    fi
  fi

  if [[ "$(readlink "$HOME/.config/zellij" 2>/dev/null)" == "$repo_dir/zellij" ]]; then
    ok "$MSG_CHECK_LINK_OK" "$HOME/.config/zellij"
  else
    bad "$MSG_CHECK_LINK_BAD" "$HOME/.config/zellij" "$repo_dir/zellij"
  fi

  # The whole design depends on this: in locked mode Zellij captures no key at
  # all, and that is what lets Ctrl+h/j/k/l reach Neovim.
  if grep -q '^default_mode "locked"' "$repo_dir/zellij/config.kdl"; then
    ok "$MSG_CHECK_ZELLIJ_LOCKED_OK"
  else
    bad "$MSG_CHECK_ZELLIJ_LOCKED_BAD"
  fi
fi

group "$MSG_CHECK_GROUP_NVIM"

nvim_bin="$(tool_bin nvim)"

if [[ -z "$nvim_bin" ]]; then
  skip "$MSG_CHECK_NVIM_MISSING"
else
  if [[ "$(readlink "$HOME/.config/nvim" 2>/dev/null)" == "$repo_dir/nvim" ]]; then
    ok "$MSG_CHECK_LINK_OK" "$HOME/.config/nvim"
  else
    bad "$MSG_CHECK_LINK_BAD" "$HOME/.config/nvim" "$repo_dir/nvim"
  fi

  # LazyVim maps <C-h/j/k/l> -> <C-w>h/j/k/l on its own. If a multiplexer
  # navigation plugin ever lands here, that is a regression: every one that
  # exists today has broken detection on Zellij >= 0.42.2.
  if grep -rqE 'zellij-nav|vim-zellij-navigator|smart-splits' "$repo_dir/nvim" 2>/dev/null; then
    bad "$MSG_CHECK_NVIM_NAV_BAD"
  else
    ok "$MSG_CHECK_NVIM_NAV_OK"
  fi
fi

group "$MSG_CHECK_GROUP_ZSH"

if [[ ! -d "$HOME/.oh-my-zsh/.git" ]]; then
  bad "$MSG_CHECK_OMZ_MISSING" "$HOME/.oh-my-zsh"
else
  ok "$MSG_CHECK_OMZ_OK"
fi

# The DIRECTORY name and the FILE name both have to match the string in the
# plugins=() array. Right directory with the wrong file gives "plugin not
# found".
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ -r "$repo_dir/zsh/custom/plugins/$p/$p.plugin.zsh" ]]; then
    ok "$MSG_CHECK_PLUGIN_OK" "$p"
  else
    bad "$MSG_CHECK_PLUGIN_BAD" "$p"
  fi
done

if [[ -r "$repo_dir/zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  ok "$MSG_CHECK_P10K_CLONED"
else
  bad "$MSG_CHECK_P10K_MISSING"
fi

# syntax-highlighting wraps the ZLE widgets once, at source time, with no
# rebind in precmd: a widget created after it is not colored. That is why it
# has to be last in the array.
last_plugin="$(sed -n '/^plugins=(/,/^)/p' "$repo_dir/zsh/zshrc" |
  grep -vE '^\)|^plugins=\(' | sed 's/#.*//' | awk 'NF{l=$1} END{print l}')"

if [[ "$last_plugin" == zsh-syntax-highlighting ]]; then
  ok "$MSG_CHECK_HL_LAST_OK"
else
  bad "$MSG_CHECK_HL_LAST_BAD" "$last_plugin"
fi

# The test that matters: a real interactive zsh, with the repo's config.
#
# 2>&1 is mandatory: the "[oh-my-zsh] plugin 'X' not found" message goes to
# STDOUT, not >&2. Without capturing both, a missing plugin turns into silent
# output corruption instead of a visible error.
zsh_bin="$(tool_bin zsh)"

if [[ -z "$zsh_bin" ]]; then
  skip "$MSG_CHECK_ZSH_MISSING"
else
  fake_zdotdir="$(mktemp -d "$tmpdir/zdotdir.XXXXXX")"
  printf 'source "%s/zsh/zshrc"\n' "$repo_dir" >"$fake_zdotdir/.zshrc"

  # shellcheck disable=SC2016  # the script goes to zsh -c literally
  tmo 25 env ZDOTDIR="$fake_zdotdir" "$zsh_bin" -i -c '
    print -r -- "THEME=$ZSH_THEME"
    print -r -- "P10K=${+functions[p10k]}"
    print -r -- "HL=${+ZSH_HIGHLIGHT_VERSION}"
    print -r -- "DIRBG=$POWERLEVEL9K_DIR_BACKGROUND"
  ' >"$tmpdir/zsh.out" 2>&1
  zsh_rc=$?
  zsh_out="$(cat "$tmpdir/zsh.out")"
  rm -rf "$fake_zdotdir"

  if ((zsh_rc == 142)); then
    bad "$MSG_CHECK_ZSH_HUNG"
  elif grep -q 'not found' <<<"$zsh_out"; then
    bad "$MSG_CHECK_OMZ_COMPLAINED" "$(grep 'not found' <<<"$zsh_out" | head -1)"
  else
    if grep -q 'THEME=powerlevel10k/powerlevel10k' <<<"$zsh_out"; then
      ok "$MSG_CHECK_THEME_OK"
    else
      bad "$MSG_CHECK_THEME_BAD"
    fi

    if grep -q 'P10K=1' <<<"$zsh_out"; then
      ok "$MSG_CHECK_P10K_LOADED"
    else
      bad "$MSG_CHECK_P10K_NOT_LOADED"
    fi

    if grep -q 'HL=1' <<<"$zsh_out"; then
      ok "$MSG_CHECK_HL_OK"
    else
      bad "$MSG_CHECK_HL_BAD"
    fi

    # Proof that p10k-overrides.zsh beat p10k.zsh: catppuccin blue, not '4'.
    if grep -q 'DIRBG=#89b4fa' <<<"$zsh_out"; then
      ok "$MSG_CHECK_CATPPUCCIN_OK"
    else
      bad "$MSG_CHECK_CATPPUCCIN_BAD" "$(grep DIRBG <<<"$zsh_out")"
    fi
  fi
fi

group "$MSG_CHECK_GROUP_REPO"

if git -C "$repo_dir" check-ignore -q zsh/custom; then
  ok "$MSG_CHECK_CUSTOM_IGNORED"
else
  bad "$MSG_CHECK_CUSTOM_NOT_IGNORED"
fi

if git -C "$repo_dir" check-ignore -q machine.lua; then
  ok "$MSG_CHECK_MACHINE_IGNORED"
else
  bad "$MSG_CHECK_MACHINE_NOT_IGNORED"
fi

if git -C "$repo_dir" ls-files --error-unmatch machine.lua >/dev/null 2>&1; then
  bad "$MSG_CHECK_MACHINE_TRACKED"
else
  ok "$MSG_CHECK_MACHINE_UNTRACKED"
fi

# Without these two in git the five machines drift apart: the lock pins the
# plugin SHAs and lazyvim.json records which extras are enabled.
for f in nvim/lazy-lock.json nvim/lazyvim.json; do
  if [[ ! -f "$repo_dir/$f" ]]; then
    skip "$MSG_CHECK_LOCK_ABSENT" "$f"
  elif git -C "$repo_dir" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    ok "$MSG_CHECK_LOCK_TRACKED" "$f"
  else
    bad "$MSG_CHECK_LOCK_UNTRACKED" "$f" "$f"
  fi
done

flush
echo

if [[ "$failures" -eq 0 ]]; then
  printf '  %s✔%s  %s%s%s\n' "$UI_VD" "$UI_R" "$UI_B" "$MSG_CHECK_ALL_GOOD" "$UI_R"
elif [[ "$failures" -eq 1 ]]; then
  printf '  %s✖%s  %s%s%s\n' "$UI_VM" "$UI_R" "$UI_B" "$MSG_CHECK_ONE_FAILED" "$UI_R"
  exit 1
else
  printf '  %s✖%s  %s%s%s\n' \
    "$UI_VM" "$UI_R" "$UI_B" "$(ui_fmt "$MSG_CHECK_N_FAILED" "$failures")" "$UI_R"
  exit 1
fi
