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
    for f in scripts/bootstrap-windows.ps1 scripts/setup-windows.ps1 pwsh/profile.ps1; do
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
  printf 'source "$ZSH/oh-my-zsh.sh"\n' >"$h/.zshrc"
  SHELL=/bin/zsh HOME="$h" bash -c "source '$repo_dir/scripts/_common.sh'; configure_shell '$repo_dir'" >/dev/null 2>&1
  block="$(awk '/>>> termstack >>>/{f=1} f{print} /<<< termstack <<</{f=0}' "$h/.zshrc")"
  if grep -q 'mise activate zsh' <<<"$block"; then
    ok "configure_shell activates mise even when the rc keeps its own oh-my-zsh"
  else
    no "configure_shell left mise inactive — tools would stay off PATH"
  fi
  rm -rf "$h"

  # A re-run must REFRESH the block, not skip it: an old EDITOR-only block has
  # to gain the mise activation, and the count stays 1. This is the whole point
  # of pulling the fix and running setup.sh again.
  h="$(sandbox)"
  {
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
  HOME="$h" bash "$fake/scripts/update.sh" >/dev/null 2>&1
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
  out="$(HOME="$h" bash "$fake/scripts/update.sh" --rollback 2>&1)"
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
  out="$(HOME="$h" bash "$fake/scripts/update.sh" 2>&1)"
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
