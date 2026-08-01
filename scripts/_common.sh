# shellcheck shell=bash
#
# Functions shared by the bootstraps and the update.
# This file is meant to be `source`d, not executed.

# ── Messages ──────────────────────────────────────────────────────────────
#
# Every user-facing string lives in i18n/, never inline here. Adding a
# language is copying i18n/en.sh and translating the values.
#
# English is sourced FIRST, always, and the chosen language on top. That
# ordering is the whole trick: a key missing from a translation keeps its
# English value instead of expanding to an empty string, so a half-finished
# translation degrades to bilingual output rather than to blank lines.
#
# Not gettext: it would need msgfmt to PRODUCE translations and ship binary
# .mo files that nobody edits by hand, and macOS has neither. Not `declare -A`
# either — the system bash on macOS is 3.2 and has no associative arrays.

_i18n_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../i18n" && pwd)"

# Os catálogos são conferidos à parte pela suíte; aqui o caminho só existe em
# runtime, então não há como o shellcheck segui-lo.
# shellcheck disable=SC1091
source "$_i18n_dir/en.sh"

_ui_lang="${TERMSTACK_LANG:-}"

# Falls back to the locale, but only for a language we actually ship: an
# unknown $LANG must not silently disable the catalog.
if [[ -z "$_ui_lang" ]]; then
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    pt_BR* | pt-BR* | pt_* | pt.*) _ui_lang=pt-BR ;;
  esac
fi

if [[ -n "$_ui_lang" && "$_ui_lang" != en && -r "$_i18n_dir/$_ui_lang.sh" ]]; then
  # shellcheck disable=SC1090,SC1091
  source "$_i18n_dir/$_ui_lang.sh"
fi

# ── Output ────────────────────────────────────────────────────────────────
#
# One dialect for all five scripts. There used to be three in a single
# install: setup with a box and symbols, preflight and check with space-padded
# OK/WARN/BLOCK labels, and the bootstrap with "==>" — the last one also
# sending half its lines to stderr, which scrambles the order under any pipe
# or `tee`. They looked like three different programs.
#
# 256 colors rather than truecolor: it is the common denominator between
# WezTerm, Terminal.app and the console of a freshly installed Linux — and
# setup runs precisely before the good terminal exists. The values approximate
# catppuccin mocha, the same theme the installed stack uses.
#
# Symbols: ✔ ▲ ✖ ● ○ → are BMP, present in any system font. No Nerd Font
# glyphs here — half of setup runs before the font exists.

if [[ -t 1 ]]; then
  UI_B=$'\033[1m' UI_DIM=$'\033[2m' UI_R=$'\033[0m'
  UI_AZ=$'\033[38;5;111m' UI_VD=$'\033[38;5;114m'
  UI_AM=$'\033[38;5;180m' UI_VM=$'\033[38;5;210m'
else
  UI_B='' UI_DIM='' UI_R='' UI_AZ='' UI_VD='' UI_AM='' UI_VM=''
fi

# The indentation hierarchy, and it is the whole point: without it the output
# of preflight, called from inside a setup step, reads as a second program.
#
#   ●●○○○  2/5  install           step         col 0
#   explanatory text              description  col 2
#     WezTerm                     group        col 2
#       ✔ config loads            item         col 4
#         detail about the item   note         col 6

# Runs a command with its output indented and dimmed, so the dumps from brew,
# mise and headless nvim do not break the wizard's visual hierarchy.
# Welcome side effect: with no tty on the far end, those tools turn off their
# animated progress bar (\r) and print line by line.
#
# NEVER wrap a command that asks for input (sudo, p10k configure): the prompt
# does not end in \n and would sit invisible in sed's buffer.
ui_pipe() {
  # Literal ESC via $'...': BSD sed does not understand \x1b in a pattern.
  # The first two patterns strip the synchronized-output ([?2026h/l) and
  # erase-line ([K) sequences brew emits even without a tty — left in the
  # middle of the text they are just visual garbage.
  local esc=$'\033'
  "$@" 2>&1 | sed \
    -e "s/${esc}\[?2026[hl]//g" \
    -e "s/${esc}\[K//g" \
    -e "s/^/      ${UI_DIM}/; s/\$/${UI_R}/"
}

# Formats a catalog entry. With a single argument the text is printed as-is,
# never as a format — that matters because half these calls pass a path, and a
# path containing a `%` would otherwise be eaten by printf. With two or more,
# the first is the format and the rest are data.
ui_fmt() {
  local text="$1"
  shift
  # shellcheck disable=SC2059  # the format is a catalog entry, by design
  (($#)) && text="$(printf "$text" "$@")"
  printf '%s' "$text"
}

ui_ok() { printf '    %s✔%s %s\n' "$UI_VD" "$UI_R" "$(ui_fmt "$@")"; }
ui_warn() { printf '    %s▲%s %s\n' "$UI_AM" "$UI_R" "$(ui_fmt "$@")"; }
ui_bad() { printf '    %s✖%s %s\n' "$UI_VM" "$UI_R" "$(ui_fmt "$@")"; }
ui_skip() { printf '    %s·%s %s%s%s\n' "$UI_DIM" "$UI_R" "$UI_DIM" "$(ui_fmt "$@")" "$UI_R"; }
ui_note() { printf '      %s%s%s\n' "$UI_DIM" "$(ui_fmt "$@")" "$UI_R"; }
ui_run() { printf '    %s→%s %s\n' "$UI_AZ" "$UI_R" "$(ui_fmt "$@")"; }
ui_group() { printf '\n  %s%s%s\n' "$UI_B" "$(ui_fmt "$@")" "$UI_R"; }

# printf counts BYTES in %-*s. With an accent or a `·` inside the text the box
# closes short, hence the padding computed from the shell's character count.
ui_pad() {
  local text="$1" width="$2" len=${#1}
  printf '%s%*s' "$text" "$((width > len ? width - len : 0))" ''
}

ui_banner() {
  local w=58 rule
  rule="$(printf '%*s' "$w" '' | tr ' ' '─')"

  printf '\n  %s╭%s╮%s\n' "$UI_AZ" "$rule" "$UI_R"
  printf '  %s│%s  %s%s%s  %s│%s\n' \
    "$UI_AZ" "$UI_R" "$UI_B" "$(ui_pad "$1" $((w - 4)))" "$UI_R" "$UI_AZ" "$UI_R"
  printf '  %s│%s  %s%s%s  %s│%s\n' \
    "$UI_AZ" "$UI_R" "$UI_DIM" "$(ui_pad "$2" $((w - 4)))" "$UI_R" "$UI_AZ" "$UI_R"
  printf '  %s╰%s╯%s\n' "$UI_AZ" "$rule" "$UI_R"
}

# Wizard progress. Dots rather than a bare "2/5" because your position in the
# whole is readable at a glance, without reading any number.
UI_STEP=0
UI_STEPS=0

ui_step() {
  UI_STEP=$((UI_STEP + 1))

  # The braces are mandatory: `$dots●` makes bash swallow the bytes of ● as
  # part of the variable name and die with "dots\xe2: unbound variable".
  local dots='' i
  for ((i = 1; i <= UI_STEPS; i++)); do
    if ((i <= UI_STEP)); then dots="${dots}●"; else dots="${dots}○"; fi
  done

  printf '\n%s%s%s  %s%s%d/%d  %s%s\n' \
    "$UI_AZ" "$dots" "$UI_R" "$UI_B" "$UI_AZ" "$UI_STEP" "$UI_STEPS" "$1" "$UI_R"
  [[ -n "${2:-}" ]] && printf '  %s%s%s\n' "$UI_DIM" "$2" "$UI_R"

  return 0
}

# y/N question. UI_YES=1 answers yes without asking; with no tty it answers no
# — installing on its own because someone redirected the output to a file is
# not the script's call to make.
#
# `s` is accepted alongside `y` on purpose: the author types Portuguese "sim"
# out of habit, and rejecting it would only produce a silent "no".
ui_ask() {
  local answer

  [[ -n "${UI_YES:-}" ]] && return 0
  [[ -t 0 ]] || return 1

  printf '\n  %s?%s %s %s[y/N]%s ' "$UI_AZ" "$UI_R" "$1" "$UI_DIM" "$UI_R"
  read -r answer

  [[ "$answer" == [yYsS] ]]
}

# The CLI list does not live here: it lives in mise/config.toml, versioned and
# linked at ~/.config/mise/config.toml. `mise use -g` writes into that file, so
# adding a tool on one machine reaches the others through git pull.

# repository|destination|commit, for zsh.
#
# oh-my-zsh lives OUTSIDE the repo: it is a git repository of its own, and
# nesting it here would make it an accidental submodule — plus its
# ZSH_CACHE_DIR (`$ZSH/cache`) would start polluting ours. The theme and the
# plugins live INSIDE, in zsh/custom, which is the ZSH_CUSTOM the zshrc points
# at.
#
# The commit pins the exact version, the same discipline as the #tags in
# tmux.conf. These four used to float on HEAD, updated with reset --hard on
# every run of update.sh — which is code straight into the shell of five
# machines the moment any of the four upstreams turns malicious. To bump one:
# look at the upstream changelog, swap the id here, run update.sh.
zsh_repos() {
  local repo_dir="$1"

  cat <<EOF
ohmyzsh/ohmyzsh|$HOME/.oh-my-zsh|c5ba74cf02cce4c342153f79089100194f30940f
romkatv/powerlevel10k|$repo_dir/zsh/custom/themes/powerlevel10k|9253fb1c5034410c43a0c681ff8294181c54016c
zsh-users/zsh-autosuggestions|$repo_dir/zsh/custom/plugins/zsh-autosuggestions|85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
zsh-users/zsh-syntax-highlighting|$repo_dir/zsh/custom/plugins/zsh-syntax-highlighting|1d85c692615a25fe2293bdd44b34c217d5d2bf04
EOF
}

# Inside WSL you do not install WezTerm: rendering is done by the Windows
# WezTerm. Only the CLI tools and the configs make sense here.
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# Portable timeout: macOS has no `timeout` (it comes from GNU coreutils).
# Returns 142 when it fires.
#
# Never capture the output of a command wrapped here with $(...): the alarm
# only kills the direct child, and a grandchild still holding the pipe leaves
# the command substitution blocked long after the timeout. Redirect to a file.
tmo() { perl -e 'alarm shift @ARGV; exec @ARGV' "$@"; }

# On macOS, a freshly installed .app bundle that has never been opened by
# LaunchServices has its helper binaries blocked by AppleSystemPolicy when
# called straight from the shell. And the block returns no error: the process
# hangs in dyld forever, with no stdout, no stderr and no timeout.
#
#   kernel (AppleSystemPolicy) ASP: Security policy would not allow process:
#     /Applications/WezTerm.app/Contents/MacOS/wezterm
#
# Measured: the same binary copied out of the bundle runs immediately, even
# carrying com.apple.quarantine — so it is not quarantine, it is the bundle
# never having gone through LaunchServices.
#
# The fix is `open -a` once. This repository does not strip quarantine and
# does not touch security policy: on a managed Mac that is working around a
# rule.
first_launch_hint() {
  local app="$1"

  [[ "$(uname -s)" == "Darwin" ]] || return 0

  msg_first_launch_hint "$app"
}

# Where snapshots and backups live.
#
# OUTSIDE the repository tree, on purpose. These files are copies of the
# user's $HOME — .zshrc, .zshenv, .zshrc.local — and they carry SDK paths,
# work-specific variables and the login name. Keeping that inside a directory
# destined to become a public repository would depend on a single .gitignore
# line to not leak, and one `git add -f`, one GUI client or one rewritten
# .gitignore takes that defense down.
#
# Out here, the entire class of problem stops existing.
backup_root() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/termstack/backup"
}

# Where the new WezTerm window signals that the install finished, so the
# originating terminal stops waiting.
#
# A fixed path rather than an environment variable: when `wezterm start` finds
# a GUI already running, it hands the command to THAT process, which launches
# the program with its own environment — not ours. The variable would never
# reach the other side, and only on machines that already had WezTerm open.
handoff_flag() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/termstack/setup-handoff-done"
}

seed_machine_lua() {
  local repo_dir="$1"

  if [[ -f "$repo_dir/machine.lua" ]]; then
    ui_skip "$MSG_MACHINE_KEPT"
  else
    cp "$repo_dir/machine.example.lua" "$repo_dir/machine.lua"
    ui_ok "$MSG_MACHINE_CREATED"
  fi
}

# ── Tools ─────────────────────────────────────────────────────────────────

# mise ships prebuilt binaries into ~/.local, without sudo and without
# compiling. That is what lets a managed work Mac (where Homebrew wants sudo
# for the default prefix) take exactly the same path as the other four
# machines.
install_mise() {
  if command -v mise >/dev/null 2>&1; then
    ui_skip "$MSG_MISE_PRESENT" "$(mise --version 2>/dev/null | head -1)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    ui_run "$MSG_MISE_VIA_BREW"
    ui_pipe brew install mise
  else
    ui_run "$MSG_MISE_VIA_CURL"
    curl -fsSL https://mise.run | sh
  fi

  export PATH="$HOME/.local/bin:$PATH"
}

mise_bin() {
  if command -v mise >/dev/null 2>&1; then
    command -v mise
  elif [[ -x "$HOME/.local/bin/mise" ]]; then
    echo "$HOME/.local/bin/mise"
  fi
}

# Resolves a binary that may have come from mise. A non-interactive script
# never goes through the shell's `mise activate`, so PATH has no shims:
# without this the bootstrap "cannot find" the nvim it just installed itself.
tool_bin() {
  local name="$1" mise

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  mise="$(mise_bin)"
  [[ -n "$mise" ]] && "$mise" which "$name" 2>/dev/null
}

install_tools() {
  local repo_dir="$1"
  local mise
  mise="$(mise_bin)"

  if [[ -z "$mise" ]]; then
    ui_warn "$MSG_MISE_MISSING"
    return 0
  fi

  # The link has to exist BEFORE the install: the list comes from it.
  link_config "$repo_dir/mise/config.toml" "$HOME/.config/mise/config.toml"

  ui_run "$MSG_TOOLS_INSTALLING"
  ui_pipe "$mise" install
}

# Two things that have to exist in the shell and cannot be solved from inside
# the repository:
#
#   1. Activating mise. Homebrew does that on its own only for fish; zsh and
#      bash are manual. Without it the tools exist and never show up on PATH.
#   2. EDITOR/VISUAL. Not a preference: Zellij resolves the scrollback editor
#      ONCE, at startup, and falls back to the literal "vi" if the variable is
#      not set before it comes up. Same goes for git, crontab and anything
#      else that opens an editor.
#
# Written as a marked block, so it can be rewritten later without duplicating.
configure_shell() {
  local repo_dir="$1"
  local rc name
  local begin='# >>> termstack >>>'
  local end='# <<< termstack <<<'

  # The project used to be called wezterm-config, and the marker carried that
  # name. An rc written by the old version has the old marker, so looking only
  # for the new one would append a SECOND block — two `source` lines, two
  # compinit calls. Recognising both is three characters of code and saves
  # every machine that ran the previous version.
  local legacy_begin='# >>> wezterm-config >>>'

  # ~/.zshrc is always a target, whether it exists or not: a clean machine has
  # none, and skipping for that reason would leave the machine with nothing
  # configured — which is exactly the case this bootstrap exists to solve.
  local -a targets=("$HOME/.zshrc")

  # bash only joins in if it already exists or if it is the login shell.
  # Creating a ~/.bashrc on macOS, where it is not even read, would be litter.
  if [[ -f "$HOME/.bashrc" || "$(basename "${SHELL:-/bin/sh}")" == bash ]]; then
    targets+=("$HOME/.bashrc")
  fi

  for rc in "${targets[@]}"; do
    name="$(basename "$rc")"

    if [[ ! -f "$rc" ]]; then
      touch "$rc"
      ui_ok "$MSG_RC_CREATED" "$name"
    fi

    if grep -qF "$begin" "$rc" || grep -qF "$legacy_begin" "$rc"; then
      ui_skip "$MSG_RC_CONFIGURED" "$name"
      continue
    fi

    if [[ "$name" == .zshrc ]]; then
      # What blocks is NOT oh-my-zsh existing — that is the design of this
      # config. It is ~/.zshrc loading its OWN oh-my-zsh/p10k outside the
      # marked block: that would be two `source oh-my-zsh.sh`, two compinit
      # calls and two instant-prompt blocks.
      #
      # The edit is manual on purpose. A surgical `sed` on the only copy of an
      # rc holding SDK paths and hand-written functions, running inside a
      # bootstrap, is a risk not worth two minutes of work.
      if grep -qE 'oh-my-zsh\.sh|p10k-instant-prompt|antigen|zinit|zplug|prezto' "$rc" 2>/dev/null; then
        {
          printf '\n%s\n' "$begin"
          msg_rc_migration_block "$repo_dir"
          printf 'export EDITOR=nvim\n'
          printf 'export VISUAL=nvim\n'
          printf '%s\n' "$end"
        } >>"$rc"

        ui_warn "$MSG_RC_OWN_OMZ" "$name"
        ui_note "$MSG_RC_OWN_OMZ_NOTE"
        continue
      fi

      {
        printf '\n%s\n' "$begin"
        printf 'source "%s/zsh/zshrc"\n' "$repo_dir"
        printf '%s\n' "$end"
      } >>"$rc"

      ui_ok "$MSG_RC_LOADS" "$name"
      continue
    fi

    # bash: the essentials only, no prompt. This stack's prompt is
    # powerlevel10k, an oh-my-zsh theme that does not run under bash — and
    # maintaining a second prompt just for bash would be a second
    # configuration across five machines. No completion and no plugins either,
    # for the same reason.
    {
      printf '\n%s\n' "$begin"
      # shellcheck disable=SC2016  # goes to the rc literally, no expansion here
      printf '%s\n' 'command -v mise >/dev/null && eval "$(mise activate bash)"'
      printf 'export EDITOR=nvim\n'
      printf 'export VISUAL=nvim\n'
      printf '%s\n' "$end"
    } >>"$rc"

    ui_ok "$MSG_RC_BASH" "$name"
  done
}

# Clones or updates oh-my-zsh, powerlevel10k and the plugins. It is the
# bootstrap and the update at the same time.
#
# I do not use oh-my-zsh's tools/install.sh. It only adds what we are turning
# off (writing ~/.zshrc and running chsh) and brings four traps: `--unattended`
# does NOT imply `--keep-zshrc` and overwrites the rc silently; piped from curl
# it overwrites even more silently; it exits 1 if $ZSH already exists; and an
# unknown argument is swallowed without an error.
#
# Puts $dir at exactly $sha, cloning first when the directory is missing.
# GitHub serves a fetch of a bare commit id (uploadpack.allowAnySHA1InWant),
# so neither branch nor tag takes part — an upstream tag can be moved or
# deleted after the fact, a commit id cannot.
#
# fetch + reset --hard instead of `git pull`: a pull on a shallow clone gives
# no reliable exit code. The reset touches neither untracked nor ignored
# files, and `custom/` is in oh-my-zsh's own .gitignore — so a pre-existing
# ~/.oh-my-zsh/custom of the user's survives intact.
repo_at_sha() {
  local owner_repo="$1" dir="$2" sha="$3"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" &&
      git init -q "$dir" &&
      git -C "$dir" remote add origin "https://github.com/$owner_repo" ||
      return 1
  fi

  git -C "$dir" fetch -q --depth 1 origin "$sha" &&
    git -C "$dir" reset -q --hard "$sha"
}

sync_zsh_repos() {
  local repo_dir="$1"
  local owner_repo dir sha name failed=0

  while IFS='|' read -r owner_repo dir sha; do
    [[ -n "$owner_repo" ]] || continue
    name="${owner_repo##*/}"

    if [[ -d "$dir" ]] && ! git -C "$dir" diff --quiet HEAD 2>/dev/null; then
      # Dirty tree: someone edited a file of the framework itself. `reset
      # --hard` would discard that without leaving a copy. Deciding on behalf
      # of whoever edited it is not our job — warn and skip.
      #
      # Does not apply to oh-my-zsh's custom/, which its own git ignores and
      # which survives the reset either way.
      ui_warn "$MSG_REPO_DIRTY" "$name"
      ui_note "$MSG_REPO_DIRTY_NOTE" "$dir"

    elif [[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" == "$sha" ]]; then
      ui_skip "$MSG_REPO_PINNED" "$name" "${sha:0:12}"

    elif repo_at_sha "$owner_repo" "$dir" "$sha"; then
      ui_ok "$MSG_REPO_INSTALLED_REF" "$name" "${sha:0:12}"

    else
      ui_bad "$MSG_REPO_UPDATE_FAILED" "$name"
      failed=1
    fi
  done < <(zsh_repos "$repo_dir")

  return $failed
}

# ── Config links ──────────────────────────────────────────────────────────

# Never overwrites an existing config — it warns and explains how to switch.
link_config() {
  local src="$1" dest="$2" legacy="${3:-}"

  mkdir -p "$(dirname "$dest")"

  # Repository cloned straight into ~/.config/wezterm, which is what the
  # README tells you to do: nothing to link, and the warning below would tell
  # you to move the repo.
  if [[ -e "$dest" && "$dest" -ef "$src" ]]; then
    ui_skip "$MSG_LINK_IS_REPO" "${dest/#$HOME/~}"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"

    if [[ "$current" == "$src" ]]; then
      ui_ok "$MSG_LINK_OK" "${dest/#$HOME/~}"
    else
      ui_warn "$MSG_LINK_ELSEWHERE" "${dest/#$HOME/~}" "$current"
    fi

    return 0
  fi

  if [[ -e "$dest" ]]; then
    ui_warn "$MSG_LINK_EXISTS" "${dest/#$HOME/~}"
    ui_note "$MSG_LINK_EXISTS_NOTE" "$dest" "$dest"
    return 0
  fi

  # The tmux case: ~/.config/tmux/tmux.conf takes precedence over
  # ~/.tmux.conf. Creating the link without a warning would leave the old
  # config alive on disk but inert — the worst kind of breakage, because
  # nothing errors out.
  if [[ -n "$legacy" && -f "$legacy" ]]; then
    ui_warn "$MSG_LINK_LEGACY" "${legacy/#$HOME/~}"
    ui_note "$MSG_LINK_LEGACY_NOTE1" "${dest/#$HOME/~}"
    ui_note "$MSG_LINK_LEGACY_NOTE2"
    ui_note "$MSG_LINK_LEGACY_NOTE3" "$legacy" "$legacy" "$src" "$dest"
    return 0
  fi

  ln -s "$src" "$dest"
  ui_ok "$MSG_LINK_CREATED" "${dest/#$HOME/~}" "${src/#$HOME/~}"
}

link_all_configs() {
  local repo_dir="$1"

  link_config "$repo_dir/mise/config.toml" "$HOME/.config/mise/config.toml"
  link_config "$repo_dir" "$HOME/.config/wezterm"
  link_config "$repo_dir/zellij" "$HOME/.config/zellij"
  link_config "$repo_dir/nvim" "$HOME/.config/nvim"
  link_config "$repo_dir/tmux" "$HOME/.config/tmux" "$HOME/.tmux.conf"
}

# ── tmux plugins ──────────────────────────────────────────────────────────

# Clones or updates. The list comes from the @plugin lines of tmux.conf, which
# stay the single source of truth — pinned versions included.
#
# I use neither `tpm/bin/install_plugins` nor `update_plugins`: they resolve
# the plugin directory by running `tmux start-server` on the default socket,
# so they read TMUX_PLUGIN_MANAGER_PATH from a server already running with a
# different config and report "Already installed" for plugins that were never
# cloned. On top of that update_plugins always returns 0, even with every
# clone failing.
sync_tmux_plugins() {
  local repo_dir="$1"
  local plugins_dir="$repo_dir/tmux/plugins"
  local spec owner_repo ref name dir cur

  mkdir -p "$plugins_dir"

  while read -r spec; do
    [[ -n "$spec" ]] || continue

    owner_repo="${spec%%#*}"
    ref=""
    [[ "$spec" == *"#"* ]] && ref="${spec#*#}"
    # TPM uses only the repository name as the directory; the `run` lines of
    # tmux.conf depend on that layout.
    name="${owner_repo##*/}"
    dir="$plugins_dir/$name"

    # Commit pin, for an upstream that publishes no tag at all (tmux-cpu).
    # Same mechanics as the zsh repos: fetch of the exact commit, reset onto
    # it. Only a full 40-hex id lands here — nothing that could be confused
    # with a tag name.
    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
      if [[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" == "$ref" ]]; then
        ui_skip "$MSG_REPO_PINNED" "$name" "${ref:0:12}"
      elif repo_at_sha "$owner_repo" "$dir" "$ref"; then
        ui_ok "$MSG_REPO_INSTALLED_REF" "$name" "${ref:0:12}"
      else
        ui_bad "$MSG_REPO_UPDATE_FAILED" "$name"
      fi
      continue
    fi

    if [[ ! -d "$dir" ]]; then
      if [[ -n "$ref" ]]; then
        git -c advice.detachedHead=false clone -q --depth 1 --branch "$ref" \
          "https://github.com/$owner_repo" "$dir" &&
          ui_ok "$MSG_REPO_INSTALLED_REF" "$name" "$ref"
      else
        git clone -q --depth 1 "https://github.com/$owner_repo" "$dir" &&
          ui_ok "$MSG_REPO_INSTALLED" "$name"
      fi

    elif [[ -n "$ref" ]]; then
      # Pinned plugin. `git pull` on a --depth 1 --branch <tag> clone answers
      # "Already up to date." with exit 0 forever, because it sits in detached
      # HEAD with a refspec for that tag only. Only a re-clone changes
      # version — and only when the #ref in tmux.conf changes.
      #
      # `tag --points-at`, not `describe --exact-match`: catppuccin/tmux has
      # four tags on the same commit (latest, v2, v2.3, v2.3.0) and describe
      # returns just one of them, almost never the pinned one — which made
      # this block re-clone on every run.
      if git -C "$dir" tag --points-at HEAD 2>/dev/null | grep -qxF "$ref"; then
        ui_skip "$MSG_REPO_PINNED" "$name" "$ref"
      else
        cur="$(git -C "$dir" describe --tags --always 2>/dev/null)"
        rm -rf "$dir"
        git -c advice.detachedHead=false clone -q --depth 1 --branch "$ref" \
          "https://github.com/$owner_repo" "$dir" &&
          ui_ok "$MSG_REPO_REPINNED" "$name" "${cur:-?}" "$ref"
      fi

    else
      # Floating plugin. fetch + reset gives a real exit code; `git pull` on a
      # shallow clone is not reliable.
      git -C "$dir" fetch -q --depth 1 origin &&
        git -C "$dir" reset -q --hard FETCH_HEAD &&
        ui_ok "$MSG_REPO_UPDATED" "$name"
    fi
  done < <(sed -nE "s/^[[:space:]]*set -g @plugin '([^']+)'.*/\1/p" \
    "$repo_dir/tmux/tmux.conf")
}

setup_tmux_plugins() {
  local repo_dir="$1"

  if [[ -z "$(tool_bin tmux)" ]]; then
    ui_warn "$MSG_TMUX_MISSING"
    return 0
  fi

  ui_run "$MSG_TMUX_PLUGINS"
  sync_tmux_plugins "$repo_dir"
}

# ── powerlevel10k ─────────────────────────────────────────────────────────

nerd_font_installed() {
  fc-list 2>/dev/null | grep -qi 'jetbrainsmono nerd' && return 0

  # fc-list does not ship with macOS (it comes with brew's fontconfig), so the
  # file test is what counts there — and it covers Linux without fontconfig.
  local f
  for f in "$HOME"/Library/Fonts/JetBrainsMono*Nerd* \
    /Library/Fonts/JetBrainsMono*Nerd* \
    "$HOME"/.local/share/fonts/JetBrainsMono*Nerd*; do
    [[ -e "$f" ]] && return 0
  done

  return 1
}

# Downloads JetBrainsMono Nerd Font from the official release and installs it
# into the user's font directory. No sudo, no package manager — it is the path
# that works on Linux (where no two distros name the package the same) and on
# a managed Mac without Homebrew.
#
# `.tar.xz` and not `.zip`: same content, 5 MB against 123 MB.
install_nerd_font() {
  local url=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
  local dest tmp

  if nerd_font_installed; then
    ui_skip "$MSG_FONT_PRESENT"
    return 0
  fi

  case "$(uname -s)" in
    Darwin) dest="$HOME/Library/Fonts" ;;
    Linux) dest="$HOME/.local/share/fonts" ;;
    *) return 0 ;;
  esac

  if ! command -v tar >/dev/null 2>&1; then
    ui_warn "$MSG_FONT_NO_TAR"
    ui_note "$url"
    return 1
  fi

  ui_run "$MSG_FONT_DOWNLOADING"

  tmp="$(mktemp -d)"

  if ! curl -fsSL -o "$tmp/font.tar.xz" "$url"; then
    ui_bad "$MSG_FONT_DOWNLOAD_FAILED"
    ui_note "$url"
    rm -rf "$tmp"
    return 1
  fi

  mkdir -p "$dest"

  # -J for xz. Works with macOS bsdtar and with GNU tar on Linux.
  if ! tar -xJf "$tmp/font.tar.xz" -C "$dest" 2>/dev/null; then
    ui_bad "$MSG_FONT_EXTRACT_FAILED"
    rm -rf "$tmp"
    return 1
  fi

  rm -rf "$tmp"

  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dest" >/dev/null 2>&1

  ui_ok "$MSG_FONT_INSTALLED" "${dest/#$HOME/~}"
}

p10k_mode() {
  sed -nE 's/^[[:space:]]*typeset -g POWERLEVEL9K_MODE=(.*)/\1/p' \
    "$1/zsh/p10k.zsh" 2>/dev/null
}

# The p10k wizard does NOT detect fonts: it records MODE according to the
# answers you gave to its glyph questions. A non-nerdfont MODE with the Nerd
# Font installed means icons stuck on the ugly fallback.
p10k_needs_configure() {
  local repo_dir="$1" mode
  mode="$(p10k_mode "$repo_dir")"

  [[ -n "$mode" && "$mode" != nerdfont* ]] && nerd_font_installed
}

# Runs the wizard with the REPOSITORY's config loaded, under a throwaway
# ZDOTDIR. That matters: the footer of zsh/p10k.zsh declares
# POWERLEVEL9K_CONFIG_FILE as its own path, so the wizard rewrites the
# versioned file. Running `p10k configure` in your normal shell would rewrite
# ~/.p10k.zsh instead, which is not what the repository uses.
run_p10k_configure() {
  local repo_dir="$1" zdotdir rc

  if [[ ! -t 0 ]]; then
    ui_warn "$MSG_P10K_NO_TTY"
    return 1
  fi

  zdotdir="$(mktemp -d)"
  printf 'source "%s/zsh/zshrc"\n' "$repo_dir" >"$zdotdir/.zshrc"

  ZDOTDIR="$zdotdir" zsh -i -c 'p10k configure'
  rc=$?

  rm -rf "$zdotdir"
  return $rc
}

# ── Neovim plugins ────────────────────────────────────────────────────────

# `install` before `restore`: restore filters by already-installed plugin and
# therefore cannot install what is missing. Then restore pins to the SHAs of
# the lazy-lock.json that just arrived in the pull.
#
# No `Lazy! sync`: sync = install + clean + UPDATE, which rewrites the
# lockfile — destroying the very reproducibility across machines the lockfile
# is supposed to guarantee.
#
# ponytail: no exit-code gate here. lazy.nvim exits 0 even with every clone
# failing (its only os.exit(1) lives in the test runner), so the return code
# says nothing. Read the output. If a broken plugin slips through more than
# once, a `nvim -u init.lua -l` sweeping plugin._.tasks would be worth it.
sync_nvim_plugins() {
  local nvim
  nvim="$(tool_bin nvim)"

  if [[ -z "$nvim" ]]; then
    ui_warn "$MSG_NVIM_MISSING"
    return 0
  fi

  ui_run "$MSG_NVIM_PLUGINS"

  # Headless lazy.nvim prints ~6 task lines PER PLUGIN (fetch, status,
  # checkout, each with a running and a finished line) — 200 lines of noise on
  # a normal run, drowning any error. The filter drops exactly those and lets
  # through what informs: "Finished task clone" (real progress, one per plugin
  # on a clean machine), "HEAD is now at" (version change) and any error.
  # The tr swaps \r for \n: git's clone progress ("Counting objects: N%")
  # rewrites the line with \r and, without the swap, becomes ONE giant line
  # that slips past the filter. After the swap the percentages hit the grep.
  nvim_quiet() {
    "$@" 2>&1 | tr '\r' '\n' | grep -vE \
      'Running task|Finished task (fetch|status|checkout)|remote: (Enumerating|Counting|Compressing) objects|Receiving objects:|Resolving deltas:' |
      sed "s/^/      ${UI_DIM}/; s/\$/${UI_R}/"
  }

  nvim_quiet "$nvim" --headless "+Lazy! install" +qa </dev/null
  nvim_quiet "$nvim" --headless "+Lazy! restore" +qa </dev/null
}
