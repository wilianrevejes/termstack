#!/usr/bin/env bash
#
# Repository test suite.
#
#   bash tests/run.sh              everything
#   bash tests/run.sh estatico     one group only (estatico, unidade,
#                                  integracao, regressao, seguranca)
#
# The integration tests run in a throwaway HOME, never in yours. No test
# installs anything or touches ~/.zshrc, ~/.config or the repository.
#
# The "regression" cases are not hypothetical: each one reproduces a bug that
# really did show up in this repository. They are commented with what broke.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
only="${1:-}"

# Without this, a wrong group name runs no test at all and the suite exits 0 —
# "0 passed" successfully, which is the worst possible result for a test.
case "$only" in
  "" | estatico | unidade | regressao | seguranca | integracao) ;;
  *)
    echo "unknown group: $only" >&2
    echo "use: estatico unidade regressao seguranca integracao" >&2
    exit 64
    ;;
esac

# The work terms live OUTSIDE  the repository. A previous version assembled
# them from string pieces right here — which defeats GitHub's code-search
# indexing, but not a human reading the file: anyone could join the pieces
# and learn exactly the words this scan exists to keep out. A guard that
# leaks what it guards.
#
# One grep -E alternation on the first line, e.g. `foo|bar-baz`. With the
# file absent the work-term scans are SKIPPED (visibly, as na), not passed:
# on the machines that can leak these terms the file exists; a fresh clone
# has nothing to hide and nothing to hide it with.
termos_arquivo="${TERMSTACK_WORK_TERMS:-$HOME/.config/termstack/work-terms}"
termos_trabalho=""
[[ -r "$termos_arquivo" ]] && IFS= read -r termos_trabalho <"$termos_arquivo"

if [[ -t 1 ]]; then
  VD=$'\033[32m' VM=$'\033[31m' AM=$'\033[33m' DIM=$'\033[2m' B=$'\033[1m' R=$'\033[0m'
else
  VD='' VM='' AM='' DIM='' B='' R=''
fi

pass=0 fail=0 skip=0
declare -a failures=()

group() {
  [[ -n "$only" && "$only" != "$1" ]] && return 1
  printf '\n%s%s %s%s\n' "$B" "──" "$2" "$R"
  return 0
}

ok() {
  printf '  %s✔%s %s\n' "$VD" "$R" "$1"
  pass=$((pass + 1))
}

no() {
  printf '  %s✖%s %s\n' "$VM" "$R" "$1"
  [[ -n "${2:-}" ]] && printf '      %s%s%s\n' "$DIM" "$2" "$R"
  fail=$((fail + 1))
  failures+=("$1")
}

na() {
  printf '  %s—%s %s\n' "$AM" "$R" "$1"
  skip=$((skip + 1))
}

# Runs a command and compares it against the expected exit code. Usage:
#   t "description" <expected> <command...>
t() {
  local desc="$1" want="$2"
  shift 2

  local out got
  out="$("$@" 2>&1)"
  got=$?

  if [[ "$got" == "$want" ]]; then
    ok "$desc"
  else
    no "$desc" "expected exit $want, got $got: $(head -1 <<<"$out")"
  fi
}

# Throwaway HOME, with the minimum for the repository to work.
sandbox() {
  local h
  h="$(mktemp -d)"
  mkdir -p "$h/.config"
  echo "$h"
}

# A stub `nvim`, for the sandboxes that run update.sh. Its rollback path calls
# sync_nvim_plugins, and a real headless lazy.nvim pointed at a HOME with no
# plugins CLONES ALL OF THEM: 180 MB downloaded and thrown away on every run of
# this suite, hidden behind the >/dev/null of the test that wanted to check
# something else entirely. tool_bin takes `command -v` first, so a stub earlier
# on PATH is enough — and sync_nvim_plugins finding a working nvim is precisely
# what these tests do NOT want to exercise.
stub_nvim() {
  mkdir -p "$1/bin"
  printf '#!/bin/sh\nexit 0\n' >"$1/bin/nvim"
  chmod +x "$1/bin/nvim"
}

# ══ static ═════════════════════════════════════════════════════════════════

if group estatico "static — is the code even valid?"; then
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x "$repo_dir"/scripts/*.sh "$repo_dir"/tests/*.sh \
      "$repo_dir"/i18n/*.sh >/dev/null 2>&1; then
      ok "shellcheck clean"
    else
      no "shellcheck" "$(shellcheck -x "$repo_dir"/scripts/*.sh "$repo_dir"/i18n/*.sh 2>&1 | head -3)"
    fi
  else
    na "shellcheck not installed"
  fi

  # macOS ships bash 3.2. Bash 4+ syntax passes shellcheck and breaks there.
  for f in "$repo_dir"/scripts/*.sh "$repo_dir"/tests/*.sh "$repo_dir"/i18n/*.sh; do
    if /bin/bash -n "$f" 2>/dev/null; then
      ok "bash 3.2 syntax: $(basename "$f")"
    else
      no "bash 3.2 syntax: $(basename "$f")" "$(/bin/bash -n "$f" 2>&1 | head -1)"
    fi
  done

  for f in "$repo_dir"/zsh/zshrc "$repo_dir"/zsh/p10k-overrides.zsh; do
    if zsh -n "$f" 2>/dev/null; then
      ok "zsh syntax: $(basename "$f")"
    else
      no "zsh syntax: $(basename "$f")" "$(zsh -n "$f" 2>&1 | head -1)"
    fi
  done

  # The .lua have no guaranteed interpreter; wezterm validates them in check.sh.
  if command -v luac >/dev/null 2>&1; then
    for f in "$repo_dir"/wezterm.lua "$repo_dir"/config/*.lua; do
      if luac -p "$f" 2>/dev/null; then
        ok "lua syntax: $(basename "$f")"
      else
        no "lua syntax: $(basename "$f")"
      fi
    done
  else
    na "luac not installed (check.sh covers it via wezterm)"
  fi

  zj="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin zellij")"
  if [[ -n "$zj" ]]; then
    if "$zj" setup --check >/dev/null 2>&1; then
      ok "Zellij config.kdl is valid"
    else
      no "Zellij config.kdl" "$("$zj" setup --check 2>&1 | head -2)"
    fi
  else
    na "zellij not installed"
  fi

  # The .ps1 are excluded from the bash -n loop above; parse them with pwsh's
  # own parser (the analogue of bash -n / luac -p). Skipped where pwsh is
  # absent, like the author's macOS/Linux boxes.
  if command -v pwsh >/dev/null 2>&1; then
    for f in scripts/bootstrap-windows.ps1 scripts/setup-windows.ps1 \
      scripts/_common-windows.ps1 scripts/update-windows.ps1 \
      tests/windows-units.ps1 pwsh/profile.ps1; do
      if (cd "$repo_dir" && pwsh -NoProfile -NonInteractive -Command \
        "\$t=\$null;\$e=\$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '$f'),[ref]\$t,[ref]\$e)>\$null;exit([int](\$e.Count -gt 0))") 2>/dev/null; then
        ok "powershell syntax: $(basename "$f")"
      else
        no "powershell syntax: $(basename "$f")"
      fi
    done

    # The generated Windows zellij config must inject default_shell (the shared
    # config.kdl leaves it as $SHELL, wrong on native Windows) and keep the
    # keybinds. -EmitZellijConfig prints it without touching the machine.
    zc="$(cd "$repo_dir" && pwsh -NoProfile -NonInteractive -File scripts/setup-windows.ps1 -EmitZellijConfig 2>/dev/null)"
    if grep -qE '^default_shell ' <<<"$zc" && grep -q 'SwitchToMode' <<<"$zc"; then
      ok "zellij Windows config generates (default_shell + keybinds)"
    else
      no "zellij Windows config generation is broken"
    fi
  else
    na "pwsh not installed (PowerShell scripts not parsed)"
  fi
fi

# ══ unit ═══════════════════════════════════════════════════════════════════

if group unidade "unit — _common.sh functions in isolation"; then
  # link_config never overwrites. It is the repository's central promise.
  h="$(sandbox)"
  echo "config do usuario" >"$h/.config/alvo"
  HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; link_config /tmp/origem '$h/.config/alvo'" >/dev/null 2>&1
  if [[ -f "$h/.config/alvo" ]] && ! [[ -L "$h/.config/alvo" ]]; then
    ok "link_config does not overwrite an existing file"
  else
    no "link_config OVERWROTE an existing file"
  fi
  rm -rf "$h"

  # ...but it does create when the path is free.
  h="$(sandbox)"
  HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; link_config '$repo_dir/tmux' '$h/.config/tmux'" >/dev/null 2>&1
  if [[ "$(readlink "$h/.config/tmux")" == "$repo_dir/tmux" ]]; then
    ok "link_config creates the link when the path is free"
  else
    no "link_config did not create the link"
  fi
  rm -rf "$h"

  # A clean machine has no ~/.zshrc. The old configure_shell skipped the
  # nonexistent file and the machine was left with no configuration at all.
  h="$(sandbox)"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  if [[ -f "$h/.zshrc" ]]; then
    ok "configure_shell creates ~/.zshrc on a clean machine"
  else
    no "configure_shell did not create ~/.zshrc"
  fi

  # Running twice must not duplicate the block.
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  n="$(grep -c '>>> termstack >>>' "$h/.zshrc")"
  if [[ "$n" == 1 ]]; then
    ok "configure_shell is idempotent (1 block after 2 runs)"
  else
    no "configure_shell duplicated the block" "found: $n"
  fi
  rm -rf "$h"

  # When ~/.zshrc already loads its own oh-my-zsh, the full config stays off
  # (two compinit calls otherwise) — but mise still has to be activated, or the
  # tools install and never reach PATH.
  h="$(sandbox)"
  # shellcheck disable=SC2016  # $ZSH is literal, it goes into the fake rc as-is
  printf 'source "$ZSH/oh-my-zsh.sh"\n' >"$h/.zshrc"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  block="$(awk '/>>> termstack >>>/{f=1} f{print} /<<< termstack <<</{f=0}' "$h/.zshrc")"
  if grep -q 'mise activate zsh' <<<"$block"; then
    ok "configure_shell activates mise even when the rc keeps its own oh-my-zsh"
  else
    no "configure_shell left mise inactive — tools would stay off PATH"
  fi
  rm -rf "$h"

  # An rc migrated BY HAND keeps a comment saying what the source line replaced
  # — and the recipe this repository prints names oh-my-zsh.sh out loud. Matched
  # as text, that comment reads as "still has its own framework" and the
  # degraded block lands on top of a correct migration.
  h="$(sandbox)"
  {
    printf '# replaces the instant prompt and the source of oh-my-zsh.sh\n'
    printf 'source "%s/zsh/zshrc"\n' "$repo_dir"
  } >"$h/.zshrc"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  block="$(awk '/>>> termstack >>>/{f=1} f{print} /<<< termstack <<</{f=0}' "$h/.zshrc")"
  if grep -q "source \"$repo_dir/zsh/zshrc\"" <<<"$block"; then
    ok "a comment naming oh-my-zsh.sh does not read as the rc having its own"
  else
    no "the degraded block landed on an rc that was already migrated" "$block"
  fi
  rm -rf "$h"

  # A re-run must REFRESH the block, not skip it: an old EDITOR-only block has
  # to gain the mise activation, and the count stays 1. This is the whole point
  # of pulling the fix and running setup.sh again.
  h="$(sandbox)"
  {
    # shellcheck disable=SC2016  # same literal $ZSH as above
    printf 'source "$ZSH/oh-my-zsh.sh"\n'
    printf '# >>> termstack >>>\n'
    printf 'export EDITOR=nvim\n'
    printf '# <<< termstack <<<\n'
  } >"$h/.zshrc"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  nblocks="$(grep -c '>>> termstack >>>' "$h/.zshrc")"
  if grep -q 'mise activate zsh' "$h/.zshrc" && [[ "$nblocks" == 1 ]]; then
    ok "configure_shell refreshes a stale block on re-run (mise added, still 1 block)"
  else
    no "configure_shell did not refresh the stale block" "mise:$(grep -c 'mise activate' "$h/.zshrc") blocks:$nblocks"
  fi
  rm -rf "$h"

  # On macOS ~/.bashrc is not even read; creating one would be junk.
  h="$(sandbox)"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  if [[ ! -f "$h/.bashrc" ]]; then
    ok "configure_shell does not create ~/.bashrc when the login shell is zsh"
  else
    no "configure_shell created an unnecessary ~/.bashrc"
  fi
  rm -rf "$h"

  # On WSL the login shell is bash.
  h="$(sandbox)"
  SHELL=/bin/bash HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  if [[ -f "$h/.bashrc" ]]; then
    ok "configure_shell creates ~/.bashrc when the login shell is bash"
  else
    no "configure_shell did not create ~/.bashrc"
  fi
  rm -rf "$h"

  # The tool list moved out of a shell array into the versioned TOML.
  tools="$(awk '/^\[tools\]/{f=1;next} /^\[/{f=0} f && /=/{sub(/[[:space:]]*=.*/,"");print}' \
    "$repo_dir/mise/config.toml")"
  for want in neovim zellij tmux lazygit ripgrep fd fzf zoxide bat node; do
    grep -qx "$want" <<<"$tools" ||
      no "mise/config.toml missing the tool $want"
  done
  if [[ "$(wc -l <<<"$tools" | tr -d ' ')" == 10 ]]; then
    ok "mise/config.toml lists the 10 CLIs"
  else
    no "mise/config.toml has $(wc -l <<<"$tools") tools, expected 10"
  fi

  # The Windows half: _common-windows.ps1 functions in isolation, in a
  # throwaway %LOCALAPPDATA%. One pwsh process for the whole file — starting one
  # per check costs half a second each — and each line it prints becomes a line
  # of this suite. Anything that is not ok|/no| is a crash in the unit script
  # itself, and counts as a failure instead of vanishing.
  if command -v pwsh >/dev/null 2>&1; then
    win_repo="$repo_dir"
    command -v cygpath >/dev/null 2>&1 && win_repo="$(cygpath -w "$repo_dir")"

    while IFS='|' read -r verdict desc detail; do
      case "$verdict" in
        ok) ok "$desc" ;;
        no) no "$desc" "$detail" ;;
        '') ;;
        *) no "windows units printed something unexpected" "$verdict$desc" ;;
      esac
    done < <(TS_REPO="$win_repo" pwsh -NoProfile -NonInteractive \
      -File "$repo_dir/tests/windows-units.ps1" 2>&1)
  else
    na "pwsh not installed (Windows _common units not exercised)"
  fi
fi

# ══ regression ═════════════════════════════════════════════════════════════

if group regressao "regression — bugs that already happened here"; then
  # No. 1: `wezterm show-keys` exits 0 even with a broken config. If the
  # check trusted the exit code, a broken config would slip through unnoticed.
  wt="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin wezterm")"
  [[ -z "$wt" && -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]] &&
    wt=/Applications/WezTerm.app/Contents/MacOS/wezterm

  if [[ -n "$wt" ]]; then
    tmpcfg="$(mktemp -d)"
    printf 'return nil +\n' >"$tmpcfg/wezterm.lua"
    out="$("$wt" --config-file "$tmpcfg/wezterm.lua" show-keys 2>/dev/null)"

    if grep -q '^Leader:' <<<"$out"; then
      no "a broken WezTerm config should lose the Leader line"
    else
      ok "broken WezTerm config falls back to default (spotted by 'Leader:')"
    fi
    rm -rf "$tmpcfg"

    # No. 1b: the config has to load when it is reached from OUTSIDE its own
    # directory — via --config-file or WEZTERM_CONFIG_FILE, with the repo not
    # at ~/.config/wezterm. require('config.*') only resolves if wezterm.lua
    # adds its own dir to package.path: WezTerm puts only the *config dir* there,
    # which is not the file's dir in that case. Run from a neutral CWD so a
    # stray ./config cannot mask it (every other test runs from the repo).
    elsewhere="$(mktemp -d)"
    keys="$(cd "$elsewhere" && "$wt" --config-file "$repo_dir/wezterm.lua" show-keys 2>/dev/null)"
    if grep -q '^Leader:' <<<"$keys"; then
      ok "config loads from a neutral CWD (not only from the repo dir)"
    else
      no "config does NOT load from a neutral CWD" "wezterm.lua must add its own dir to package.path"
    fi
    rm -rf "$elsewhere"
  else
    na "wezterm not found"
  fi

  # No. 2: `git describe --exact-match` returns an arbitrary tag when several
  # point at the same commit — catppuccin has 4 — and the sync re-cloned on
  # every run. The right comparison is `git tag --points-at`.
  d="$repo_dir/tmux/plugins/tmux"
  if [[ -d "$d/.git" ]]; then
    if git -C "$d" tag --points-at HEAD 2>/dev/null | grep -qxF v2.3.0; then
      ok "pinned plugin is recognized by 'tag --points-at' (no re-clone)"
    else
      no "catppuccin is not on tag v2.3.0"
    fi
  else
    na "tmux plugins not cloned"
  fi

  # No. 3: preflight looked for the 'termstack' marker in the whole file,
  # so as soon as the bootstrap wrote ANY block, the "own omz in the rc"
  # blocker vanished — on exactly the machine that needed it.
  h="$(sandbox)"
  {
    # shellcheck disable=SC2016  # literal text, do not expand here
    echo 'source "$ZSH/oh-my-zsh.sh"'
    echo '# >>> termstack >>>'
    echo 'export EDITOR=nvim'
    echo '# <<< termstack <<<'
  } >"$h/.zshrc"
  # Capture before filtering: with `set -o pipefail`, the pipeline status comes
  # from preflight (which exits 1 when it finds a blocker), not from grep.
  out="$(HOME="$h" bash "$repo_dir/scripts/preflight.sh" 2>&1)"
  if grep -q 'loads oh-my-zsh/p10k on its own' <<<"$out"; then
    ok "preflight detects own omz even with the marked block present"
  else
    no "preflight stopped detecting own omz because of the marked block"
  fi
  rm -rf "$h"

  # ...and the inverse: an rc that has only our block must not block.
  h="$(sandbox)"
  {
    echo '# >>> termstack >>>'
    echo "source \"$repo_dir/zsh/zshrc\""
    echo '# <<< termstack <<<'
  } >"$h/.zshrc"
  out="$(HOME="$h" bash "$repo_dir/scripts/preflight.sh" 2>&1)"
  if grep -q 'loads oh-my-zsh/p10k on its own' <<<"$out"; then
    no "preflight blocked an rc that only loads the repository config"
  else
    ok "preflight does not block an rc that only loads the repository config"
  fi
  rm -rf "$h"

  # No. 4: the TPM scripts call `tmux` BY NAME. With tmux coming from mise and
  # outside the PATH, the plugins fail silently and the bar comes up themeless.
  tm="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin tmux")"
  if [[ -n "$tm" && -d "$repo_dir/tmux/plugins/tpm" ]]; then
    h="$(sandbox)"
    ln -s "$repo_dir/tmux" "$h/.config/tmux"
    sock=termstack-test
    "$tm" -L "$sock" kill-server 2>/dev/null
    HOME="$h" PATH="$(dirname "$tm"):$PATH" "$tm" -L "$sock" \
      -f "$repo_dir/tmux/tmux.conf" new-session -d -s t 2>/dev/null

    if [[ -n "$("$tm" -L "$sock" show-options -gv @thm_green 2>/dev/null)" ]]; then
      ok "tmux plugins load with tmux on the PATH"
    else
      no "tmux catppuccin did not load even with tmux on the PATH"
    fi

    "$tm" -L "$sock" kill-server 2>/dev/null
    rm -rf "$h"
  else
    na "tmux or plugins missing"
  fi

  # No. 5: `grep -c` prints the number AND exits 1 when it finds nothing. The
  # `|| echo 0` produced "0\n0" and broke preflight's arithmetic.
  h="$(sandbox)"
  : >"$h/.zshrc"
  out="$(HOME="$h" bash "$repo_dir/scripts/preflight.sh" 2>&1)"
  if grep -q 'syntax error' <<<"$out"; then
    no "preflight has a syntax error with an empty ~/.zshrc"
  else
    ok "preflight runs clean with an empty ~/.zshrc"
  fi
  rm -rf "$h"

  # No. 6: syntax-highlighting wraps the widgets once, at source time. If it
  # is not the last of the array, a widget created later gets no color.
  last="$(sed -n '/^plugins=(/,/^)/p' "$repo_dir/zsh/zshrc" |
    grep -vE '^\)|^plugins=\(' | sed 's/#.*//' | awk 'NF{l=$1} END{print l}')"
  if [[ "$last" == zsh-syntax-highlighting ]]; then
    ok "zsh-syntax-highlighting is the last of the plugins array"
  else
    no "last plugin is '$last'" "it has to be zsh-syntax-highlighting"
  fi

  # No. 7: in locked mode Zellij captures no key, and that is what lets
  # Ctrl+h/j/k/l reach Neovim without a navigation plugin.
  if grep -q '^default_mode "locked"' "$repo_dir/zellij/config.kdl"; then
    ok "Zellij in default_mode locked"
  else
    no "Zellij is not in locked — it will steal Ctrl+hjkl from Neovim"
  fi

  if grep -rqE 'zellij-nav|vim-zellij-navigator|smart-splits' "$repo_dir/nvim" 2>/dev/null; then
    no "multiplexer navigation plugin in nvim/ (all of them broken today)"
  else
    ok "no multiplexer navigation plugin in nvim/"
  fi

  # No. 8: the README says to clone into ~/.config/wezterm, and then the
  # check_config target IS the repository. --clean planned an `mv` of the repo
  # to wezterm.bak and setup went on calling the bootstrap at a path that was
  # gone: the first command in the README destroyed its own installation.
  h="$(sandbox)"
  cp -R "$repo_dir" "$h/.config/wezterm" 2>/dev/null
  rm -rf "$h/.config/wezterm/.git"
  HOME="$h" bash "$h/.config/wezterm/scripts/preflight.sh" --clean --yes >/dev/null 2>&1
  if [[ -d "$h/.config/wezterm/scripts" && ! -e "$h/.config/wezterm.bak" ]]; then
    ok "preflight --clean does not move the repo cloned into ~/.config/wezterm"
  else
    no "preflight --clean MOVED the repository itself" "left: $(ls -1 "$h/.config")"
  fi
  rm -rf "$h"

  # No. 9: the automatic rollback did `git reset --hard`, which wipes an
  # uncommitted edit in a tracked file. The pull's --autostash does not save
  # it: it reapplies and drops the stash. Offline there is not even a pull,
  # and the tree was destroyed all the same.
  h="$(sandbox)"
  fake="$h/repo"
  cp -R "$repo_dir" "$fake" 2>/dev/null
  rm -rf "$fake/.git"
  git -C "$fake" init -q -b main . 2>/dev/null
  git -C "$fake" add -A 2>/dev/null
  git -C "$fake" -c user.email=t@t -c user.name=t commit -qm t 2>/dev/null
  echo '-- uncommitted work --' >>"$fake/config/keys.lua"
  stub_nvim "$h"
  HOME="$h" PATH="$h/bin:$PATH" bash "$fake/scripts/update.sh" >/dev/null 2>&1
  if grep -q 'uncommitted work' "$fake/config/keys.lua"; then
    ok "the update rollback preserves an uncommitted modification"
  else
    no "the update rollback WIPED uncommitted work" "git reset --hard with no stash"
  fi
  rm -rf "$h"

  # No. 10: preflight writes into the same backup_root with the `preflight-`
  # prefix, which sorts AFTER any timestamp. `update.sh --rollback` with no
  # argument picked one of those — with no git-rev at all — and printed
  # "restoring" without restoring anything, in the success format.
  h="$(sandbox)"
  fake="$h/repo"
  cp -R "$repo_dir" "$fake" 2>/dev/null
  rm -rf "$fake/.git"
  br="$h/.local/state/termstack/backup"
  mkdir -p "$br/20200101-000000" "$br/preflight-20990101-000000"
  echo none >"$br/20200101-000000/git-rev"
  stub_nvim "$h"
  out="$(HOME="$h" PATH="$h/bin:$PATH" bash "$fake/scripts/update.sh" --rollback 2>&1)"
  if grep -q 'restoring .*/20200101-000000' <<<"$out"; then
    ok "--rollback with no argument takes the update snapshot, not preflight's"
  else
    no "--rollback took a directory with no git-rev" "$(grep -m1 -iE 'restoring|snapshot' <<<"$out")"
  fi
  rm -rf "$h"

  # No. 11: `head -n -N` (negative count) is a GNU extension. On macOS the BSD
  # head answers "illegal line count" and snapshot pruning became a noisy
  # no-op — the kind of thing that only shows up on half of the five machines.
  # The pattern requires a digit, quote or $ after the sign, so it matches
  # code (`head -n -5`, `head -n -"$n"`) and not the prose in the comments.
  if grep -qE 'head +-n +-[0-9"$]' "$repo_dir"/scripts/*.sh; then
    no "head with a negative count (only exists on GNU)" \
      "$(grep -nE 'head +-n +-[0-9"$]' "$repo_dir"/scripts/*.sh | head -1)"
  else
    ok "no head with a negative count in the scripts"
  fi

  # No. 12: `dots="$dots●"` makes bash swallow the bytes of the ● as part of
  # the variable name — under `set -u` the setup banner died with "dots\xe2:
  # unbound variable" on the first line, before any installation. It holds
  # for any `$var` followed by a non-ASCII character.
  # grep -v of comment lines first: _common.sh itself documents the trap by
  # quoting the pattern, and the test must not fail because of the prose.
  colado="$(grep -nE '\$[A-Za-z_][A-Za-z_0-9]*[^ -~[:space:]]' "$repo_dir"/scripts/*.sh |
    grep -vE ':[0-9]+:[[:space:]]*#')"

  if [[ -n "$colado" ]]; then
    no "\$var glued to a non-ASCII character (bash absorbs the bytes in the name)" \
      "$(head -1 <<<"$colado")"
  else
    ok "no \$var glued to a non-ASCII character"
  fi

  # No. 13: the five scripts had three output dialects — "==>", the
  # OK/AVISO/BLOQUEIA labels, and symbols — and the bootstrap still sent half
  # the lines to stderr, which scrambles the order in any pipe. All of that
  # now goes out through the ui_* of _common.sh.
  if grep -nE '^\s*echo "(==>|AVISO:|FALHA)' "$repo_dir"/scripts/*.sh; then
    no "old output dialect back in the scripts (use the ui_* of _common.sh)"
  else
    ok "script output only through the ui_* helpers"
  fi

  # No. 14: `wezterm start` is held for the life of the window it opened, and
  # the new window ends in `exec $SHELL` — never. In the foreground, the
  # origin terminal hung forever with the half-done installation on screen.
  # The call lives in a `{ ...; } &` block — the `&` is not on the same line.
  # shellcheck disable=SC2016  # literal pattern, searched in the source
  if grep -A3 '"\$wezterm_bin" start .*--resumed' "$repo_dir/scripts/setup.sh" |
    grep -qE '^\s*\} &$'; then
    ok "the WezTerm handoff runs in the background"
  else
    no "the WezTerm handoff blocks the origin terminal again"
  fi

  # The signal has to be written BEFORE the exec: exec replaces the process
  # image and takes the EXIT trap with it, so from there on nobody is left to
  # write anything — and the origin terminal waits the full 30 minutes.
  sig="$(grep -n '^((resumed)) && signal_origin' "$repo_dir/scripts/setup.sh" | cut -d: -f1)"
  # shellcheck disable=SC2016  # literal pattern, searched in the source
  ex="$(grep -n 'exec "\${SHELL' "$repo_dir/scripts/setup.sh" | cut -d: -f1)"

  if [[ -n "$sig" && -n "$ex" ]] && ((sig < ex)); then
    ok "the done signal is written before the shell exec"
  else
    no "done signal after the exec (exec takes the trap along)" "signal=$sig exec=$ex"
  fi

  # And the trap covers dying midway: script error, Ctrl+C, window closed by
  # hand. Without it any of those leaves the other terminal waiting for good.
  h="$(sandbox)"
  XDG_STATE_HOME="$h/state" HOME="$h" \
    bash "$repo_dir/scripts/setup.sh" --resumed </dev/null >/dev/null 2>&1 &
  resumed_pid=$!
  sleep 4
  kill "$resumed_pid" 2>/dev/null
  wait "$resumed_pid" 2>/dev/null

  if [[ -e "$h/state/termstack/setup-handoff-done" ]]; then
    ok "setup --resumed signals the origin terminal even dying midway"
  else
    no "setup --resumed died without signaling (the other terminal stays stuck)"
  fi
  rm -rf "$h"

  # No. 15: a cheat sheet that lies is worse than no cheat sheet — whoever
  # reads it trusts it. It is curated by hand, so nothing stops someone from
  # changing config/keys.lua or tmux.conf and leaving the text behind.
  #
  # The list below is the source of the check and holds both ways: every key
  # has to be ANNOUNCED on the cheat sheet AND really BOUND. Touching one of
  # the two sides without the other takes this test down.
  wez="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin wezterm")"
  [[ -z "$wez" && -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]] &&
    wez=/Applications/WezTerm.app/Contents/MacOS/wezterm

  if [[ -n "$wez" ]]; then
    folha="$(bash "$repo_dir/scripts/cheatsheet.sh" | sed $'s/\033\\[[0-9;]*m//g')"
    # inline alarm: the `tmo` of _common.sh is not in this script's scope, and
    # an unregistered .app bundle hangs in dyld forever.
    keys="$(perl -e 'alarm 20; exec @ARGV' \
      "$wez" --config-file "$repo_dir/wezterm.lua" show-keys 2>/dev/null | grep LEADER)"
    drift=""

    # The cheat sheet line that lists the prefix keys. Comparing against the
    # WHOLE text is no good: `grep -F z` matches "zellij", "zoxide" and "zj",
    # and the test would pass with the key deleted. Here it is an exact token,
    # on this line.
    linha="$(grep -F 'split' <<<"$folha" | head -1)"

    # The key comes from show-keys, not from a list of mine: that way swapping
    # x for q in config/keys.lua without updating the cheat sheet also fails.
    for acao in SplitHorizontal SplitVertical ActivatePaneDirection \
      CloseCurrentPane TogglePaneZoomState SpawnTab ActivateCopyMode; do
      bind="$(grep -F "$acao" <<<"$keys" | head -1)"

      if [[ -z "$bind" ]]; then
        drift="$drift gone:$acao"
        continue
      fi

      # Last token before the `->`. The mods can contain `|` (SHIFT | LEADER),
      # so cutting by fixed column does not work.
      tecla="$(sed -E 's/^.*[[:space:]]([^[:space:]]+)[[:space:]]+->.*/\1/' <<<"$bind")"

      awk -v k="$tecla" '{for (i = 1; i <= NF; i++) if ($i == k) f = 1} END {exit !f}' \
        <<<"$linha" || drift="$drift $acao=$tecla"
    done

    if [[ -z "$drift" ]]; then
      ok "the cheat sheet does not drift from what WezTerm has bound"
    else
      no "cheat sheet and config diverged" "$drift"
    fi
  else
    na "wezterm missing, no way to check the cheat sheet drift"
  fi

  # And do the discovery shortcuts the cheat sheet announces really exist?
  folha="$(bash "$repo_dir/scripts/cheatsheet.sh" | sed $'s/\033\\[[0-9;]*m//g')"
  falta=""
  grep -q 'Ctrl+Space ?' <<<"$folha" &&
    grep -q 'bind "?"' "$repo_dir/zellij/config.kdl" || falta="$falta zellij"
  grep -q 'Ctrl+a ?' <<<"$folha" &&
    grep -q "key = '?'" "$repo_dir/config/keys.lua" || falta="$falta wezterm"

  if [[ -z "$falta" ]]; then
    ok "the announced discovery shortcuts exist in the config"
  else
    no "the cheat sheet announces a shortcut that does not exist" "$falta"
  fi

  # ── The layers `wezterm show-keys` cannot see ────────────────────────────
  #
  # The drift test above only reaches the WezTerm layer. Everything the sheet
  # says about Zellij, tmux and the shell was verified by hand once, which is
  # not a guard: those files get edited without anyone opening i18n/.
  #
  # All four render the sheet in ENGLISH on purpose. The anchors are words
  # ("Zellij only", "Shell"), and in another language they are other words —
  # the drift test above greps for "split" and, under a pt_BR locale, silently
  # checks nothing at all.
  folha_en="$(TERMSTACK_LANG=en bash "$repo_dir/scripts/cheatsheet.sh" |
    sed $'s/\033\\[[0-9;]*m//g')"

  # No. 29: every script resolves its own directory to run from anywhere, and
  # they all did it with a LOGICAL pwd. Invoked through a symlink to the
  # repository — which is exactly what ~/.config/wezterm is, and what the
  # cheat sheet tells you to type — repo_dir kept the symlinked path, while
  # `readlink` on the config links answers with the physical one. check.sh then
  # reported two links as broken while they were perfectly correct, and a
  # bootstrap run that way would have CREATED links pointing at the link.
  #
  # The line is taken from each script instead of retyped here: this has to
  # keep testing what they really do, not what this test remembers.
  h="$(sandbox)"
  cp -R "$repo_dir" "$h/repo" 2>/dev/null
  ln -s "$h/repo" "$h/link"
  esperado="$(cd "$h/repo" && pwd -P)"
  falta=""

  for s in check preflight setup update cheatsheet bootstrap-macos bootstrap-linux; do
    linha="$(grep -m1 '^repo_dir=' "$h/repo/scripts/$s.sh")"
    {
      printf '%s\n' "$linha"
      # shellcheck disable=SC2016  # $repo_dir expands in the probe, not here
      printf 'printf "%%s\\n" "$repo_dir"\n'
    } >"$h/repo/scripts/probe-$s.sh"

    obtido="$(bash "$h/link/scripts/probe-$s.sh" 2>/dev/null)"
    [[ "$obtido" == "$esperado" ]] || falta="$falta $s:$obtido"
  done
  rm -rf "$h"

  if [[ -z "$falta" ]]; then
    ok "every script resolves the repository through a symlink to the real path"
  else
    no "a script called through a symlink keeps the symlinked path" "$falta"
  fi

  # No. 28: the drift test above starts from a list of seven actions, so a bind
  # outside that list can live in config/keys.lua without ever reaching the
  # sheet — which is exactly what LEADER H J K L, LEADER 1..9, the launcher and
  # the doubled prefix did. This one starts from the other end: EVERY LEADER
  # binding WezTerm reports has to be announced. It reuses the show-keys output
  # the test above already paid twenty seconds for.
  if [[ -n "$wez" ]]; then
    bloco_wez="$( {
      grep -F 'split' <<<"$folha_en" | head -1
      awk '/WezTerm only/ { f = 1 } /Zellij only/ { f = 0 } f' <<<"$folha_en"
    } | sed -E 's/WezTerm only//')"

    falta=""
    digitos=0

    while IFS= read -r linha; do
      [[ -n "$linha" ]] || continue

      # Last token before the `->`, same rule as the test above: the mods
      # column can contain `|` (SHIFT | LEADER), so a fixed column does not cut
      # it. The action is what comes after, up to its first argument.
      tecla="$(sed -E 's/^.*[[:space:]]([^[:space:]]+)[[:space:]]+->.*/\1/' <<<"$linha")"
      acao="$(sed -E 's/.*->[[:space:]]+//; s/[[:space:]({].*//' <<<"$linha")"

      # Three of them are announced as prose or as a range, not as a token.
      case "$acao" in
        SendKey)
          grep -q 'Ctrl+a again' <<<"$folha_en" || falta="$falta doubled-prefix"
          continue
          ;;
        SpawnCommandInNewTab)
          grep -q 'Ctrl+a ?' <<<"$folha_en" || falta="$falta ?"
          continue
          ;;
        ActivateTab)
          digitos=$((digitos + 1))
          continue
          ;;
      esac

      [[ "$tecla" == Space ]] && tecla=space

      awk -v k="$tecla" '{ for (i = 1; i <= NF; i++) if ($i == k) f = 1 } END { exit !f }' \
        <<<"$bloco_wez" || falta="$falta $tecla"
    done <<<"$keys"

    # The sheet writes the nine tabs as a range. Both halves are claims: that
    # the range is printed, and that all nine really are bound.
    grep -qF '1…9' <<<"$bloco_wez" || falta="$falta range-1-9"
    ((digitos == 9)) || falta="$falta ActivateTab=$digitos"

    # And the other way, for the WezTerm-only lines: an item starts with its
    # key. The three that are not a key are the ones handled above.
    sobra=""
    while IFS= read -r tok; do
      case "$tok" in
        '' | '1…9' | 'Ctrl+a') continue ;;
        space) tok=Space ;;
      esac

      awk -v k="$tok" '{ for (i = 1; i < NF; i++) if ($i == k && $(i + 1) == "->") f = 1 } END { exit !f }' \
        <<<"$keys" || sobra="$sobra $tok"
    done < <(awk '/only|resize|launcher|again/ {
      gsub(/^ +/, "")
      n = split($0, item, /   +/)
      for (i = 1; i <= n; i++) {
        if (item[i] ~ /[^ ]/) {
          split(item[i], w, " ")
          print w[1]
        }
      }
    }' <<<"$bloco_wez")

    if [[ -z "$falta$sobra" ]]; then
      ok "every LEADER binding WezTerm reports is announced on the sheet"
    else
      no "WezTerm binding the cheat sheet does not match" "unannounced:$falta invented:$sobra"
    fi
  fi

  # No. 23: the Zellij keys, both ways — a bind that no line announces, and a
  # line announcing a bind that does not exist.
  binds="$(awk '/^    tmux clear-defaults/ { f = 1 } f && /bind "/ { print }' \
    "$repo_dir/zellij/config.kdl")"

  # Where they are announced: the shared prefix line plus the Zellij block, up
  # to where the tmux one starts. The label goes, so only keys are left.
  bloco="$( {
    grep -F 'split' <<<"$folha_en" | head -1
    awk '/Zellij only/ { f = 1 } /tmux only/ { f = 0 } f' <<<"$folha_en"
  } | sed -E 's/Zellij only//')"

  falta=""
  while IFS= read -r linha; do
    [[ -n "$linha" ]] || continue
    tecla="$(sed -E 's/.*bind "([^"]+)".*/\1/' <<<"$linha")"

    # Two of them are announced outside that block: the prefix itself, up in
    # the header, and `?`, down in "Forgot a key?".
    case "$tecla" in
      "Ctrl Space")
        grep -q 'Zellij Ctrl+Space' <<<"$folha_en" || falta="$falta prefix"
        continue
        ;;
      "?")
        grep -q 'Ctrl+Space ?' <<<"$folha_en" || falta="$falta ?"
        continue
        ;;
      Space) tecla=space ;;
    esac

    awk -v k="$tecla" '{ for (i = 1; i <= NF; i++) if ($i == k) f = 1 } END { exit !f }' \
      <<<"$bloco" || falta="$falta $tecla"
  done <<<"$binds"

  # The other direction. An item on those lines starts with its key, and items
  # are separated by three spaces — that is the whole layout convention.
  sobra=""
  while IFS= read -r tecla; do
    [[ -n "$tecla" ]] || continue
    [[ "$tecla" == space ]] && tecla=Space
    grep -qF "bind \"$tecla\"" <<<"$binds" || sobra="$sobra $tecla"
  done < <(awk '{
    gsub(/^ +/, "")
    n = split($0, item, /   +/)
    for (i = 1; i <= n; i++) {
      if (item[i] ~ /[^ ]/) {
        split(item[i], w, " ")
        print w[1]
      }
    }
  }' <<<"$bloco")

  if [[ -z "$falta$sobra" ]]; then
    ok "the cheat sheet and the Zellij binds say the same thing"
  else
    no "cheat sheet and zellij/config.kdl diverged" "unannounced:$falta invented:$sobra"
  fi

  # No. 24: the Shell block promises aliases and tools that live in three other
  # files. The mapping is by hand because the names differ — the sheet says
  # `rg`, mise says `ripgrep` — so each pair is checked on both sides: the
  # sheet really announces the token, and something really provides it.
  bloco_sh="$(awk '/^  Shell$/ { f = 1; next } f && /^$/ { exit } f' <<<"$folha_en")"
  falta=""

  anunciada() {
    awk -v k="$1" '{ for (i = 1; i <= NF; i++) if ($i == k) f = 1 } END { exit !f }' \
      <<<"$bloco_sh"
  }

  for a in v lg zj stack; do
    anunciada "$a" || falta="$falta sheet:$a"
    grep -qE "^alias $a=" "$repo_dir/zsh/zshrc" || falta="$falta zshrc:$a"
  done

  while read -r tok tool; do
    [[ -n "$tok" ]] || continue
    anunciada "$tok" || falta="$falta sheet:$tok"
    grep -qE "^$tool = " "$repo_dir/mise/config.toml" || falta="$falta mise:$tool"
  done <<'MAPA'
rg ripgrep
fd fd
bat bat
z zoxide
Ctrl+R fzf
MAPA

  if [[ -z "$falta" ]]; then
    ok "the Shell block matches zsh/zshrc and mise/config.toml"
  else
    no "the Shell block of the cheat sheet promises what nothing provides" "$falta"
  fi

  # The git aliases are not ours: they come from the oh-my-zsh plugin, which is
  # a clone the bootstrap makes. Without it there is nothing to check against.
  omz_git="$HOME/.oh-my-zsh/plugins/git/git.plugin.zsh"
  if [[ -r "$omz_git" ]]; then
    falta=""
    while IFS= read -r a; do
      [[ -n "$a" ]] || continue
      grep -qE "^alias $a=" "$omz_git" || falta="$falta $a"
    done < <(awk '/^    gst /{ for (i = 1; i <= NF; i++) if ($i ~ /^g[a-z]+$/) print $i }' \
      <<<"$bloco_sh")

    if [[ -z "$falta" ]]; then
      ok "every git alias the cheat sheet lists exists in the oh-my-zsh plugin"
    else
      no "git alias on the sheet that oh-my-zsh does not define" "$falta"
    fi
  else
    na "oh-my-zsh not cloned, no way to check the git aliases"
  fi

  # No. 25: the "Open LazyVim on a project" block hands out flags, and zellij's
  # are not consistent between subcommands — `-c` is --cwd on `action new-tab`
  # and --close-on-exit on `run`. The sheet prints only the first form. If
  # upstream ever swaps them, that line turns into a trap.
  zj_bin="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin zellij")"

  if [[ -n "$zj_bin" ]]; then
    falta=""
    "$zj_bin" action new-tab --help 2>&1 | grep -qE '^ *-c, --cwd' ||
      falta="$falta new-tab:-c-is-not-cwd"
    "$zj_bin" run --help 2>&1 | grep -qE '^ *-c, --close-on-exit' ||
      falta="$falta run:-c-is-not-close-on-exit"
    "$zj_bin" attach --help 2>&1 | grep -qE '^ *-f, --force-run-commands' ||
      falta="$falta attach:-f"
    "$zj_bin" --help 2>&1 | grep -qE '^ *-n, --new-session-with-layout' ||
      falta="$falta -n"

    if [[ -z "$falta" ]]; then
      ok "the zellij flags the cheat sheet gives out still mean what it says"
    else
      no "a zellij flag on the cheat sheet changed meaning upstream" "$falta"
    fi
  else
    na "zellij missing, no way to check the flags on the sheet"
  fi

  # No. 26: the tmux line came last and had no guard at all. Server on a socket
  # of its own and a throwaway HOME: with no plugins the if-shell block in
  # tmux.conf is false, so no TPM, no continuum, and nothing of yours is
  # restored into the test — which also means prefix I and U are not there to
  # check, since TPM is what binds them. What the sheet promises about those
  # two is that tmux.conf loads TPM at all, and that is checked as text.
  tmux_bin="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin tmux")"

  if [[ -n "$tmux_bin" ]]; then
    h="$(sandbox)"
    sock="termstack-test-$$"
    teclas="$(HOME="$h" "$tmux_bin" -L "$sock" -f "$repo_dir/tmux/tmux.conf" \
      list-keys -T prefix 2>/dev/null)"
    HOME="$h" "$tmux_bin" -L "$sock" kill-server >/dev/null 2>&1
    rm -rf "$h"

    # The key alone is not enough for the ones that are OURS: tmux binds `r` to
    # refresh-client by default, so deleting our reload from tmux.conf would
    # leave `r` bound and the test green. The command has to match too.
    bound() {
      awk -v k="$1" -v c="${2:-.}" '{
        for (i = 1; i < NF; i++) {
          if ($i == "prefix" && $(i + 1) == k) {
            resto = ""
            for (j = i + 2; j <= NF; j++) resto = resto $j " "
            if (resto ~ c) f = 1
          }
        }
      } END { exit !f }' <<<"$teclas"
    }

    falta=""
    while read -r k cmd; do
      [[ -n "$k" ]] || continue
      bound "$k" "$cmd" || falta="$falta $k"
    done <<'MAPA'
r source-file
| split-window
- split-window
c new-window
h select-pane
j select-pane
k select-pane
l select-pane
H resize-pane
J resize-pane
K resize-pane
L resize-pane
MAPA

    # These are tmux's own, and the sheet lists them as such: zoom, session
    # picker, detach, window N, copy mode and the key list. Presence is the
    # whole claim.
    for k in z s d 9 '[' '?'; do
      bound "$k" || falta="$falta $k"
    done

    grep -q 'plugins/tpm/tpm"' "$repo_dir/tmux/tmux.conf" || falta="$falta tpm(I,U)"

    if [[ -z "$falta" ]]; then
      ok "every tmux key on the cheat sheet is really bound"
    else
      no "the cheat sheet announces a tmux key that is not bound" "$falta"
    fi
  else
    na "tmux missing, no way to check the keys on the sheet"
  fi

  # No. 27: the LazyVim block, which is the one the sheet cannot own — those
  # keys come from upstream and get renamed there without anyone here noticing.
  # It needs a real Neovim with the plugins already installed, so it SKIPS on a
  # machine that has not run the bootstrap: a test that would clone plugins to
  # answer is not a test, it is an install.
  #
  # Two sources, because there are two kinds of key on that block. The ones
  # without a mark are global and are asked of `maparg` directly. The ones the
  # sheet marks with `*` are buffer-local — they exist only once a language
  # server attaches, so they are read from the spec LazyVim resolves for
  # nvim-lspconfig, which is where they are declared.
  nvim_bin="$(bash -c "source '$repo_dir/scripts/_common.sh'; tool_bin nvim")"
  lazy_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/LazyVim"

  if [[ -n "$nvim_bin" && -d "$lazy_dir" ]]; then
    bloco_lv=" $(awk '/^  LazyVim/ { f = 1; next } f && /^$/ { exit } f' <<<"$folha_en" |
      tr '\n' ' ' | tr -s ' ') "

    h="$(sandbox)"
    : >"$h/keys"
    : >"$h/lsp"
    falta=""

    # lhs, where it lives, and the token the sheet prints for it. The lhs comes
    # first because it never contains a space and the token often does. This
    # table is the ONLY list: writing the lsp keys out again further down would
    # let the two copies drift, and a guard that disagrees with itself passes.
    while read -r lhs escopo token; do
      [[ -n "$lhs" ]] || continue
      grep -qF " $token " <<<"$bloco_lv" || falta="$falta sheet:$token"

      if [[ "$escopo" == global ]]; then
        printf '%s\n' "$lhs" >>"$h/keys"
      else
        printf '%s\n' "$lhs" >>"$h/lsp"
      fi
    done <<'TECLAS'
<leader><leader> global space
<leader>/ global /
<leader>, global ,
<leader>e global e
<leader>fr global f r
<leader>gg global g g
<leader>bb global b b
<leader>bd global b d
<leader>qq global q q
<leader>l global l
<leader>sw global s w
<leader>sk global s k
<leader>qs global q s
<leader>cd global c d
<leader>| global |
<leader>- global -
]d global ] d
[d global [ d
H global H L
L global H L
<C-h> global Ctrl+h/j/k/l
<C-j> global Ctrl+h/j/k/l
<C-k> global Ctrl+h/j/k/l
<C-l> global Ctrl+h/j/k/l
<C-/> global Ctrl+/
gd lsp g d*
gr lsp g r*
K lsp K*
<leader>ca lsp c a*
<leader>cr lsp c r*
TECLAS

    # VeryLazy is fired by hand: with no UI attached there is nothing to make
    # Neovim fire it on its own, and every keymap on that block is registered
    # by a plugin that waits for it.
    cat >"$h/dump.lua" <<'LUA'
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
vim.wait(5000, function()
  return vim.fn.mapcheck(" ff", "n") ~= ""
end)

local ausentes = {}
for linha in io.lines(os.getenv("TERMSTACK_KEYS")) do
  if vim.fn.maparg((linha:gsub("<leader>", vim.g.mapleader)), "n") == "" then
    ausentes[#ausentes + 1] = linha
  end
end
io.write("GLOBAL " .. table.concat(ausentes, " ") .. "\n")

local lsp = {}
local ok, opts = pcall(function()
  return LazyVim.opts("nvim-lspconfig")
end)
if ok and opts.servers and opts.servers["*"] then
  for _, k in ipairs(opts.servers["*"].keys or {}) do
    lsp[#lsp + 1] = k[1]
  end
end
io.write("LSP " .. table.concat(lsp, " ") .. "\n")
LUA

    # alarm, and not a plain call: a Neovim that comes up waiting for input in
    # a suite with no terminal hangs the whole run.
    saida="$(TERMSTACK_KEYS="$h/keys" perl -e 'alarm 90; exec @ARGV' \
      "$nvim_bin" --headless -i NONE -c "luafile $h/dump.lua" -c 'qa!' 2>/dev/null)"

    ausentes="$(sed -n 's/^GLOBAL //p' <<<"$saida")"
    lsp_keys=" $(sed -n 's/^LSP //p' <<<"$saida") "
    [[ -n "$ausentes" ]] && falta="$falta nvim:$ausentes"

    if [[ "$lsp_keys" == "  " ]]; then
      falta="$falta lsp-spec-empty"
    else
      while IFS= read -r k; do
        [[ -n "$k" ]] || continue
        grep -qF " $k " <<<"$lsp_keys" || falta="$falta lsp:$k"
      done <"$h/lsp"
    fi

    rm -rf "$h"

    if [[ -z "$falta" ]]; then
      ok "every LazyVim key on the cheat sheet is really mapped"
    else
      no "the cheat sheet announces a LazyVim key that does not exist" "$falta"
    fi
  else
    na "Neovim without the plugins installed, no way to check the LazyVim keys"
  fi

  # ── i18n ─────────────────────────────────────────────────────────────────

  # No. 20: a key used in a script and missing from en.sh becomes "unbound
  # variable" under `set -u` — the script dies on the line, in the middle of
  # an install. en.sh is the net: it is always loaded, before any translation.
  # shellcheck disable=SC2016  # literal pattern, searched in the source
  usadas="$(grep -rhoE '\$MSG_[A-Z0-9_]+|\bmsg_[a-z0-9_]+' \
    "$repo_dir"/scripts/*.sh | tr -d '$' | sort -u)"
  faltando=""

  for chave in $usadas; do
    if [[ "$chave" == msg_* ]]; then
      grep -qE "^$chave\(\)" "$repo_dir/i18n/en.sh" || faltando="$faltando $chave"
    else
      grep -qE "^$chave=" "$repo_dir/i18n/en.sh" || faltando="$faltando $chave"
    fi
  done

  if [[ -z "$faltando" ]]; then
    ok "every key used in the scripts exists in i18n/en.sh"
  else
    no "key used and missing from the English catalog" "$faltando"
  fi

  # No. 21: a key that exists only in a translation is junk — it came from a
  # rename that did not go through en.sh, and will never be printed.
  orfas=""
  for cat in "$repo_dir"/i18n/*.sh; do
    [[ "$(basename "$cat")" == en.sh ]] && continue
    while read -r chave; do
      [[ -n "$chave" ]] || continue
      grep -qE "^$chave=" "$repo_dir/i18n/en.sh" ||
        orfas="$orfas $(basename "$cat"):$chave"
    done < <(grep -oE '^MSG_[A-Z0-9_]+' "$cat")
  done

  if [[ -z "$orfas" ]]; then
    ok "no translation defines a key the English one does not have"
  else
    no "orphan key in a translation" "$orfas"
  fi

  # No. 22: the 78-column ceiling holds for EVERY language. In Portuguese the
  # words are longer and that is where it overflows first.
  for cat in "$repo_dir"/i18n/*.sh; do
    lang="$(basename "$cat" .sh)"
    larga=""
    while IFS= read -r linha; do
      ((${#linha} > 78)) && larga="${#linha}: ${linha:0:40}" && break
    done < <(TERMSTACK_LANG="$lang" bash "$repo_dir/scripts/cheatsheet.sh" |
      sed $'s/\033\[[0-9;]*m//g')

    if [[ -z "$larga" ]]; then
      ok "the cheat sheet in $lang fits in 78 columns"
    else
      no "the cheat sheet in $lang has a line that is too long" "$larga"
    fi
  done

  # ── The cheat sheet, which now opens by key in two layers ────────────────

  # No. 16: 78 columns is the ceiling. It comes out at the end of setup, which
  # may run in an 80-wide Terminal.app, and a line broken in half is worse
  # than one line too many. It has needed a manual fix three times; it becomes
  # a test.
  larga=""
  while IFS= read -r linha; do
    ((${#linha} > 78)) && larga="${#linha}: ${linha:0:50}" && break
  done < <(bash "$repo_dir/scripts/cheatsheet.sh" | sed $'s/\033\\[[0-9;]*m//g')

  if [[ -z "$larga" ]]; then
    ok "the cheat sheet fits in 78 columns"
  else
    no "the cheat sheet has a line that is too long" "$larga"
  fi

  # No. 17: the Ctrl+Space ? of Zellij runs a command with `cd -P` to resolve
  # the ~/.config/zellij link down to the repository. A wrong path there gives
  # no visible error — it opens an empty pane and closes. So the test extracts
  # the command FROM config.kdl ITSELF and runs it, in a synthetic HOME with
  # the link set up.
  cmd="$(sed -nE 's/^[[:space:]]*Run "bash" "-c" "(.*)" \{$/\1/p' \
    "$repo_dir/zellij/config.kdl" | head -1)"
  cmd="${cmd//\\\"/\"}"        # unescapes the KDL quotes
  cmd="${cmd%; read -rsn1}"    # no key wait, which would hang the suite

  if [[ -z "$cmd" ]]; then
    no "could not find the ? bind command in the Zellij config.kdl"
  else
    h="$(sandbox)"
    ln -s "$repo_dir/zellij" "$h/.config/zellij"
    saida="$(HOME="$h" bash -c "$cmd" 2>&1)"

    if grep -q 'four layers' <<<"$saida"; then
      ok "the Ctrl+Space ? of Zellij resolves the path and prints the sheet"
    else
      no "the ? bind command did not produce the sheet" "$(head -1 <<<"$saida")"
    fi
    rm -rf "$h"
  fi

  # No. 18: a Zellij floating pane is born with 20 lines and the cheat sheet
  # has 33 — with no declared height, the top is born off screen and nobody
  # notices, because the footer shows up normally.
  if sed -n '/bind "?"/,/^        }/p' "$repo_dir/zellij/config.kdl" |
    grep -q 'height'; then
    ok "the ? bind of Zellij declares the floating pane height"
  else
    no "? bind with no height: the cheat sheet is born cut off at the top"
  fi

  # No. 19: the LEADER ? of WezTerm builds the path with wezterm.config_dir.
  # If that resolves wrong, the pane opens and dies without saying anything.
  if [[ -n "$wez" ]]; then
    alvo="$(perl -e 'alarm 20; exec @ARGV' \
      "$wez" --config-file "$repo_dir/wezterm.lua" show-keys 2>/dev/null |
      sed -nE 's/.*"bash ([^;]+); read.*/\1/p' | head -1)"

    if [[ -n "$alvo" && -f "$alvo" ]]; then
      ok "the LEADER ? of WezTerm points to a cheat sheet that exists"
    else
      no "LEADER ? points to a nonexistent path" "${alvo:-(not extracted)}"
    fi
  else
    na "wezterm missing, no way to check the LEADER ? path"
  fi

  # Setup runs BEFORE the Nerd Font exists. A Private Use Area glyph — which
  # is where the Nerd Font icons live — turns into a little box on exactly the
  # first screen the user sees. Perl because BSD grep does no codepoint range.
  if perl -CSD -ne 'exit 1 if /[\x{e000}-\x{f8ff}]|[\x{f0000}-\x{ffffd}]/' \
    "$repo_dir"/scripts/*.sh; then
    ok "no Nerd Font glyph in the scripts' output"
  else
    no "Nerd Font glyph in the scripts (the font does not exist yet when they run)"
  fi
fi

# ══ security ═══════════════════════════════════════════════════════════════

if group seguranca "security — what must never happen"; then
  # Path INSIDE the directory: the `.backup/` pattern of the .gitignore only
  # matches a directory, and `check-ignore .backup` without a slash misses.
  for p in machine.lua tmux/plugins/x zsh/custom/x .backup/x; do
    if git -C "$repo_dir" check-ignore -q "$p"; then
      ok "$p is ignored by git"
    else
      no "$p is NOT ignored by git"
    fi
  done

  # The repository is public: no user path and no work tool in the versioned
  # files.
  if git -C "$repo_dir" grep -qI '/Users/[a-z]' -- . 2>/dev/null; then
    no "absolute user path in a versioned file" \
      "$(git -C "$repo_dir" grep -nI '/Users/[a-z]' -- . | head -1)"
  else
    ok "no absolute user path in the versioned files"
  fi

  # No `:!tests/`: with the work terms out of this file and the credential
  # patterns assembled from pieces, this file no longer matches itself — and
  # the scan covers tests/ too, which used to be a permanent blind spot.
  #
  # The credential half always runs; the work-term half only joins in when
  # the local terms file provides it (see the top of this script).
  sensivel="BEGIN [A-Z ]*PRIVATE KEY"
  sensivel="$sensivel|gh""p_|github""_pat_|AKI""A[0-9A-Z]{16}|xo""x[bp]-"
  [[ -n "$termos_trabalho" ]] && sensivel="$sensivel|$termos_trabalho"
  if git -C "$repo_dir" grep -qIiE "$sensivel" -- . 2>/dev/null; then
    no "sensitive content in a versioned file" \
      "$(git -C "$repo_dir" grep -nIiE "$sensivel" -- . | head -1)"
  else
    ok "no sensitive content in the versioned files"
  fi

  # The other half is the history: it carries what the tree no longer has.
  # Three commits of this repository mentioned a work tool in a comment that
  # was removed later — publishing with history would publish the term.
  #
  # Count into a variable, not `| grep -q`: grep -q exits on the first hit,
  # git dies of SIGPIPE, `set -o pipefail` makes the whole pipeline non-zero
  # and the test passed precisely when it FOUND something.
  if [[ -z "$termos_trabalho" ]]; then
    na "work-term history scan skipped: no $termos_arquivo"
  else
    hist="$(git -C "$repo_dir" log -p --all 2>/dev/null |
      "${GREP:-/usr/bin/grep}" -ciE "$termos_trabalho")"
    if [[ "${hist:-0}" != 0 ]]; then
      no "work term in the git HISTORY ($hist occurrences)" \
        "publish from a new repository, without history"
    else
      ok "git history with no work term"
    fi
  fi

  # --yes is "do not ask me", not "yes to everything destructive". The branch
  # lives in setup.sh; its text moved to the catalog, so the key is what is
  # searched for here.
  # shellcheck disable=SC2016  # searching for the literal text in the script
  if grep -q 'assume_yes)); then' "$repo_dir/scripts/setup.sh" &&
    grep -q 'MSG_SETUP_YES_NO_CLEAN' "$repo_dir/scripts/setup.sh"; then
    ok "--yes without --clean does not move the user's config"
  else
    no "--yes may be triggering --clean"
  fi

  # Scan of the WORKING TREE, not just of what git tracks.
  #
  # `git grep` is blind to an ignored file, and that is exactly how two
  # backups of the owner's ~/.zshrc — with a work SDK PATH and a login name —
  # sat for months inside the repository without anyone seeing them.
  #
  # Explicit /usr/bin/grep: the `grep` on this machine's PATH is ugrep, which
  # respects .gitignore and would give a false "clean" right before the push.
  gr=/usr/bin/grep
  if [[ ! -x "$gr" ]]; then
    na "no /usr/bin/grep to scan the working tree"
  else
    # Excludes third-party clones: they are ignored by git, they do not get
    # published, and their documentation quotes example absolute paths.
    scan_ex=(--exclude-dir=.git --exclude-dir=plugins --exclude-dir=custom)

    if [[ -z "$termos_trabalho" ]]; then
      na "work-term tree scan skipped: no $termos_arquivo"
    else
      achou="$("$gr" -rIl -iE "$termos_trabalho" "$repo_dir" \
        "${scan_ex[@]}" 2>/dev/null)"
      if [[ -n "$achou" ]]; then
        no "work term in the working tree" "$(head -1 <<<"$achou")"
      else
        ok "working tree with no work term (scanned with /usr/bin/grep)"
      fi
    fi

    achou="$("$gr" -rIl -E '/Users/[a-z]' "$repo_dir" \
      "${scan_ex[@]}" 2>/dev/null)"
    if [[ -n "$achou" ]]; then
      no "user path in the working tree" "$(head -1 <<<"$achou")"
    else
      ok "working tree with no absolute user path"
    fi
  fi

  # A backup of the user's $HOME must not land inside the repository: they are
  # copies of .zshrc and .zshrc.local, which carry work variables.
  # shellcheck disable=SC2016  # searching for the literal text in the script
  if grep -qE 'backup_(root|dir)="\$repo_dir' "$repo_dir"/scripts/*.sh; then
    no "\$HOME backup being written inside the repository"
  else
    ok "backups stay outside the repository tree"
  fi

  if [[ -d "$repo_dir/.backup" ]]; then
    no ".backup/ exists inside the repository" "move it outside the repository"
  else
    ok "no .backup/ inside the repository"
  fi

  # Same promise on the Windows side: the snapshot carries a copy of the user's
  # $PROFILE, which is where an SDK path or a token lives on that machine.
  # Get-BackupRoot must build from %LOCALAPPDATA%, never from the script's own
  # directory.
  bkroot="$(grep -A3 'function Get-BackupRoot' "$repo_dir/scripts/_common-windows.ps1")"

  if grep -qE '\$env:LOCALAPPDATA' <<<"$bkroot"; then
    ok "the Windows backup root is built from %LOCALAPPDATA%"
  else
    no "the Windows backup root does not come from %LOCALAPPDATA%" "$bkroot"
  fi

  if grep -qE '\$PSScriptRoot|\$repoDir|\$RepoDir' <<<"$bkroot"; then
    no "the Windows backup root is derived from the repository directory"
  else
    ok "the Windows snapshots stay outside the repository tree"
  fi

  # `winget upgrade --all` would drag every unrelated program on the machine
  # along with the update — an update script has no business upgrading the
  # user's browser or their company VPN client.
  # Comment lines stripped first: the reason NOT to do it is written down in
  # _common-windows.ps1, and a scan that reads its own rationale as a violation
  # is a test that fails the moment someone documents the rule.
  if grep -hvE '^[[:space:]]*#' "$repo_dir"/scripts/*.ps1 |
    grep -qE 'winget upgrade.*--all'; then
    no "a Windows script runs winget upgrade --all"
  else
    ok "the Windows update only upgrades the stack's own packages"
  fi

  # ~/.config/nvim and ~/.local/state/nvim fall into the same --clean and have
  # the same basename. With the backup named by basename, the second cp -R
  # went INSIDE the first — scrambling the copy that undoes the destructive
  # step.
  h="$(sandbox)"
  mkdir -p "$h/.config/nvim" "$h/.local/state/nvim"
  echo config >"$h/.config/nvim/init.lua"
  echo state >"$h/.local/state/nvim/shada"

  HOME="$h" bash "$repo_dir/scripts/preflight.sh" --clean --yes >/dev/null 2>&1

  # shellcheck disable=SC2012  # directory name is a timestamp, no surprise
  bdir="$(ls -1d "$h/.local/state/termstack/backup"/preflight-* 2>/dev/null | head -1)"
  if [[ -f "$bdir/config__nvim/init.lua" && -f "$bdir/local__state__nvim/shada" ]]; then
    ok "same-named backups do not collide (config__nvim and local__state__nvim)"
  else
    # shellcheck disable=SC2012
    no "backup of ~/.config/nvim and ~/.local/state/nvim collided" \
      "$(ls "$bdir" 2>/dev/null | tr '\n' ' ')"
  fi
  rm -rf "$h"

  # Preflight records the fixes as ACTION + arguments separated by TAB and
  # never as a command string. The previous version stored the ready-made
  # command and ran `eval`: a path with an apostrophe broke, and one with
  # $(...) would be executed.
  if grep -qE '^\s*eval ' "$repo_dir"/scripts/*.sh; then
    no "there is an eval in scripts/" "$(grep -nE '^\s*eval ' "$repo_dir"/scripts/*.sh | head -1)"
  else
    ok "no eval in the scripts"
  fi

  # The real test: HOME with an apostrophe, a space and a command substitution.
  h="$(mktemp -d)"
  # "So-and-so's MacBook" with an apostrophe is a common machine name, and
  # that is how a path with quotes gets here without anyone meaning harm.
  hostil="$h/O'Brien's \$(touch $h/EXECUTOU) Mac"
  mkdir -p "$hostil/.config/nvim"
  echo x >"$hostil/.config/nvim/init.lua"

  HOME="$hostil" bash "$repo_dir/scripts/preflight.sh" --clean --yes >/dev/null 2>&1

  if [[ -e "$h/EXECUTOU" ]]; then
    no "preflight --clean EXECUTED a command substitution coming from the path"
  elif [[ -d "$hostil/.config/nvim.bak" ]]; then
    ok "preflight --clean handles a path containing an apostrophe and \$(...)"
  else
    no "preflight --clean did not move the directory in a special-character path"
  fi
  rm -rf "$h"

  # Every command that can hang has a timeout: a binary from an unregistered
  # .app bundle locks up in dyld forever, with no error.
  # shellcheck disable=SC2016  # literal text, do not expand here
  if grep -q 'tmo 20 "\$wezterm_bin"' "$repo_dir/scripts/check.sh"; then
    ok "the wezterm call in check has a timeout"
  else
    no "check.sh calls wezterm without a timeout"
  fi
fi

# ══ integration ════════════════════════════════════════════════════════════

if group integracao "integration — the full flow, in a throwaway HOME"; then
  h="$(sandbox)"
  t "preflight exits 0 when there is no conflict" 0 \
    env HOME="$h" bash "$repo_dir/scripts/preflight.sh"
  rm -rf "$h"

  t "setup rejects an unknown argument" 64 \
    bash "$repo_dir/scripts/setup.sh" --does-not-exist

  t "cheatsheet runs" 0 bash "$repo_dir/scripts/cheatsheet.sh"

  # The Windows wizard's contract, exercised on any machine with pwsh: an
  # unknown argument exits 64 (like setup.sh), and -DryRun diagnoses and exits
  # 0 without touching winget, WSL or the filesystem. The bash -c "cd && exec
  # pwsh -File" wrapper keeps a POSIX path from being mangled on its way to the
  # native exe.
  if command -v pwsh >/dev/null 2>&1; then
    t "setup-windows rejects an unknown argument" 64 \
      bash -c "cd '$repo_dir' && exec pwsh -NoProfile -NonInteractive -File scripts/setup-windows.ps1 -does-not-exist"
    t "setup-windows -DryRun exits 0 and mutates nothing" 0 \
      bash -c "cd '$repo_dir' && exec pwsh -NoProfile -NonInteractive -File scripts/setup-windows.ps1 -DryRun"

    t "update-windows rejects an unknown argument" 64 \
      bash -c "cd '$repo_dir' && exec pwsh -NoProfile -NonInteractive -File scripts/update-windows.ps1 -does-not-exist"
    t "update-windows -DryRun exits 0" 0 \
      bash -c "cd '$repo_dir' && exec pwsh -NoProfile -NonInteractive -File scripts/update-windows.ps1 -DryRun"

    # With %LOCALAPPDATA% pointed at an empty directory there is no snapshot to
    # go back to, and the rollback has to SAY so and exit non-zero. The bug it
    # guards against is the opposite: printing "restoring" and exiting 0 having
    # restored nothing.
    h="$(sandbox)"
    win_h="$h"
    command -v cygpath >/dev/null 2>&1 && win_h="$(cygpath -w "$h")"

    rb_out="$(env LOCALAPPDATA="$win_h" pwsh -NoProfile -NonInteractive \
      -File "$repo_dir/scripts/update-windows.ps1" -Rollback 2>&1)"
    rb_rc=$?

    # The exit code alone is not enough: on a machine where the stack is not
    # wired the script exits 1 anyway, and the test would pass while the
    # rollback silently restored nothing. The message is what proves it noticed.
    if [[ "$rb_rc" -ne 0 ]] && grep -q 'no snapshot to restore from' <<<"$rb_out"; then
      ok "update-windows -Rollback with no snapshot says so and fails"
    else
      no "update-windows -Rollback with no snapshot" "exit $rb_rc: $(head -1 <<<"$rb_out")"
    fi

    # -DryRun is the mode you can run to see what it would touch: it must not
    # create the backup root, let alone a snapshot.
    env LOCALAPPDATA="$win_h" pwsh -NoProfile -NonInteractive \
      -File "$repo_dir/scripts/update-windows.ps1" -DryRun >/dev/null 2>&1

    if [[ -d "$h/termstack/backup" ]]; then
      no "update-windows -DryRun wrote a snapshot"
    else
      ok "update-windows -DryRun writes nothing"
    fi
    rm -rf "$h"
  else
    na "pwsh not installed (setup-windows.ps1 behavior not exercised)"
  fi

  # The cheat sheet opens with the shell in a new WezTerm window — and ONLY
  # there: inside Zellij/tmux every split would reprint the ~75 lines. It
  # prints before the instant prompt block, so it works even with the rest of
  # the rc breaking (in a HOME without oh-my-zsh, like this sandbox).
  #
  # Capture first, grep later: a `zsh -i | grep -q` closes the pipe on the
  # first match and the SIGPIPE in the middle of the zsh init gives erratic
  # results. And with alarm: an interactive zsh in a strange HOME hung here.
  h="$(sandbox)"
  printf 'source "%s/zsh/zshrc"\n' "$repo_dir" >"$h/.zshrc"

  out="$(perl -e 'alarm 25; exec @ARGV' /usr/bin/env \
    HOME="$h" ZDOTDIR="$h" WEZTERM_PANE=7 ZELLIJ='' TMUX='' \
    zsh -i -c exit </dev/null 2>/dev/null)"

  if grep -q 'four layers' <<<"$out"; then
    ok "cheatsheet opens in a new WezTerm shell"
  else
    no "cheatsheet did not open in a WezTerm shell"
  fi

  out="$(perl -e 'alarm 25; exec @ARGV' /usr/bin/env \
    HOME="$h" ZDOTDIR="$h" WEZTERM_PANE=7 ZELLIJ=1 TMUX='' \
    zsh -i -c exit </dev/null 2>/dev/null)"

  if grep -q 'four layers' <<<"$out"; then
    no "cheatsheet reprints inside Zellij (spam on every split)"
  else
    ok "cheatsheet stays quiet inside Zellij"
  fi
  rm -rf "$h"

  # The quiet run that setup fires after the "Resolve now? y": the scan has
  # just appeared on screen, so it shows only summary, plan and Applying —
  # and it has to really APPLY, not just stay quiet.
  h="$(sandbox)"
  mkdir -p "$h/.config/nvim"
  echo x >"$h/.config/nvim/init.lua"
  out="$(HOME="$h" XDG_STATE_HOME="$h/state" TERMSTACK_SCAN_QUIET=1 \
    bash "$repo_dir/scripts/preflight.sh" --clean --yes 2>&1)"

  if grep -q 'Existing configuration' <<<"$out"; then
    no "SCAN_QUIET still prints the whole scan"
  elif grep -q 'Applying' <<<"$out" && [[ -d "$h/.config/nvim.bak" ]]; then
    ok "SCAN_QUIET shows only plan+Applying and still applies"
  else
    no "SCAN_QUIET applied nothing" "$(head -3 <<<"$out")"
  fi
  rm -rf "$h"

  # Without a tty and without --yes, setup must not go off installing on its
  # own.
  #
  # The assertion is about EFFECT, not about a message. The previous version
  # looked for the string "nothing conflicts" — which is exactly what setup
  # prints on the path where it does NOT stop and installs. In a clean HOME
  # preflight always exits 0, so the test was tautological: it ran the whole
  # bootstrap (mise install, brew bundle, `open -a WezTerm`, the oh-my-zsh
  # clone and `git reset --hard` inside zsh/custom and tmux/plugins of the
  # REAL repository, because repo_dir is not sandboxed) and printed ✔.
  h="$(sandbox)"
  HOME="$h" bash "$repo_dir/scripts/setup.sh" </dev/null >/dev/null 2>&1
  sujeira=""
  for p in .oh-my-zsh .local/share/mise/installs .zshrc; do
    [[ -e "$h/$p" ]] && sujeira="$sujeira $p"
  done
  if [[ -z "$sujeira" ]]; then
    ok "setup without a tty and without --yes installed nothing"
  else
    no "setup without a tty INSTALLED without confirming" "created:$sujeira"
  fi
  rm -rf "$h"

  # update.sh offline must not fail nor try the network.
  h="$(sandbox)"
  fake="$h/repo"
  cp -R "$repo_dir" "$fake" 2>/dev/null
  rm -rf "$fake/.git" "$fake/.backup"
  git -C "$fake" init -q -b main . 2>/dev/null
  git -C "$fake" add -A 2>/dev/null
  git -C "$fake" -c user.email=t@t -c user.name=t commit -qm t 2>/dev/null
  stub_nvim "$h"
  out="$(HOME="$h" PATH="$h/bin:$PATH" bash "$fake/scripts/update.sh" 2>&1)"
  if grep -q 'offline' <<<"$out"; then
    ok "update.sh detects that it is offline and skips the network"
  else
    no "update.sh did not detect the missing remote" "$(head -3 <<<"$out")"
  fi
  # The snapshot goes outside the repository on purpose: it contains copies of
  # the ~/.zshrc, which carries work variables.
  if [[ -d "$h/.local/state/termstack/backup" ]]; then
    ok "update.sh takes a snapshot, outside the repository tree"
  elif [[ -d "$fake/.backup" ]]; then
    no "update.sh wrote the snapshot INSIDE the repository"
  else
    no "update.sh did not create a snapshot"
  fi
  rm -rf "$h"
fi

# ══ result ═════════════════════════════════════════════════════════════════

printf '\n%s──%s\n' "$B" "$R"
printf '  %s%d passed%s' "$VD" "$pass" "$R"
((fail)) && printf '   %s%d failed%s' "$VM" "$fail" "$R"
((skip)) && printf '   %s%d skipped%s' "$AM" "$skip" "$R"
echo

if ((fail)); then
  echo
  for f in "${failures[@]}"; do printf '  %s✖%s %s\n' "$VM" "$R" "$f"; done
  echo
  exit 1
fi

echo
exit 0
