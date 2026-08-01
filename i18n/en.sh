# shellcheck shell=bash
# shellcheck disable=SC2034  # consumed by the scripts that source this file
#
# Message catalog — English. This file is the reference AND the fallback.
#
# To add a language: copy this file to <tag>.sh (a BCP-47-ish tag, like
# pt-BR.sh or de.sh), translate the values, and select it with
#
#   TERMSTACK_LANG=pt-BR bash scripts/setup.sh
#
# or let it be picked from $LANG. You do NOT have to translate everything:
# _common.sh sources en.sh first and your file on top, so any key you leave
# out falls back to English instead of printing an empty line.
#
# Rules for values:
#
#   * They are printf FORMATS. `%s` marks where data lands, and the order of
#     the placeholders must match the call site. Where a language needs a
#     different word order, use `%1$s`, `%2$s` — that is what those exist for.
#   * A literal percent sign has to be written `%%`.
#   * Keep them one line. The ui_* helpers add the indentation, the symbol and
#     the colors; a value carrying its own layout will not line up.
#   * Multi-line blocks are functions (msg_*), not variables, so they can
#     interpolate at call time.
#
# Nothing here should mention a specific machine, user or company: this file
# is as public as the rest of the repository.

# ── Config links ──────────────────────────────────────────────────────────

MSG_LINK_IS_REPO='%s is the repository itself'
MSG_LINK_OK='%s → repository'
MSG_LINK_ELSEWHERE='%s already links to %s, kept'
MSG_LINK_EXISTS='%s exists and is not a link — not overwriting'
MSG_LINK_EXISTS_NOTE='move it and run again:  mv "%s" "%s.bak"'
MSG_LINK_LEGACY='you already have %s — link not created'
MSG_LINK_LEGACY_NOTE1='%s takes precedence over it, so the link would'
MSG_LINK_LEGACY_NOTE2='leave your current config inert.'
MSG_LINK_LEGACY_NOTE3='to switch:  mv "%s" "%s.bak" && ln -s "%s" "%s"'
MSG_LINK_CREATED='%s → %s'

# ── machine.lua ───────────────────────────────────────────────────────────

MSG_MACHINE_KEPT='machine.lua already exists, kept'
MSG_MACHINE_CREATED='machine.lua created from machine.example.lua'

# ── mise and the CLI tools ────────────────────────────────────────────────

MSG_MISE_PRESENT='mise already installed (%s)'
MSG_MISE_VIA_BREW='installing mise through Homebrew'
MSG_MISE_VIA_CURL='installing mise into ~/.local/bin'
MSG_MISE_MISSING='mise not found, skipping the CLI install'
MSG_TOOLS_INSTALLING='installing the CLI tools (mise/config.toml)'

# ── Shell configuration ───────────────────────────────────────────────────

MSG_RC_CREATED='%s created (clean machine)'
MSG_RC_CONFIGURED='%s already configured'
MSG_RC_OWN_OMZ='%s has its own oh-my-zsh/p10k, repository config NOT enabled'
MSG_RC_OWN_OMZ_NOTE='only EDITOR was set — the migration recipe is in the block'
MSG_RC_LOADS='%s loads the repository config'
MSG_RC_BASH='%s configured (mise + EDITOR)'

# The comment block written INTO the user's ~/.zshrc when it already loads an
# oh-my-zsh of its own. It stays in their file forever, so it is as
# user-facing as anything printed on screen. $1 is the repository path.
msg_rc_migration_block() {
  printf '# Your ~/.zshrc already loads oh-my-zsh/p10k on its own, so this\n'
  printf '# repository config is NOT enabled: it would mean two compinit\n'
  printf '# calls and two instant-prompt blocks.\n'
  printf '#\n'
  printf '# To migrate, delete from your rc: the instant-prompt block, the\n'
  printf '# export ZSH / ZSH_THEME / plugins=() / source oh-my-zsh.sh, the\n'
  printf '# source of ~/.p10k.zsh and the mise eval. Then replace those\n'
  printf '# lines with:\n'
  printf '#   source "%s/zsh/zshrc"\n' "$1"
}

# ── Cloned repositories (oh-my-zsh, p10k, plugins) ────────────────────────

MSG_REPO_INSTALLED='%s installed'
MSG_REPO_INSTALLED_REF='%s installed (%s)'
MSG_REPO_CLONE_FAILED='%s failed to clone'
MSG_REPO_DIRTY='%s skipped (tree has local modifications)'
MSG_REPO_DIRTY_NOTE='to update it: git -C "%s" checkout .'
MSG_REPO_UPDATED='%s updated'
MSG_REPO_UPDATE_FAILED='%s failed to update'
MSG_REPO_PINNED='%s pinned at %s'
MSG_REPO_REPINNED='%s re-pinned (%s → %s)'

# ── tmux ──────────────────────────────────────────────────────────────────

MSG_TMUX_MISSING='tmux not found, skipping the tmux plugins'
MSG_TMUX_PLUGINS='tmux plugins'

# ── Font ──────────────────────────────────────────────────────────────────

MSG_FONT_PRESENT='JetBrainsMono Nerd Font already installed'
MSG_FONT_NO_TAR='tar not found, install the font by hand'
MSG_FONT_DOWNLOADING='downloading JetBrainsMono Nerd Font (~5 MB)'
MSG_FONT_DOWNLOAD_FAILED='font download failed — install it by hand'
MSG_FONT_EXTRACT_FAILED='font extraction failed'
MSG_FONT_INSTALLED='font installed in %s'

# ── powerlevel10k ─────────────────────────────────────────────────────────

MSG_P10K_NO_TTY='no interactive terminal, skipping p10k configure'

# ── Neovim ────────────────────────────────────────────────────────────────

MSG_NVIM_MISSING='nvim not found, skipping the Neovim plugins'
MSG_NVIM_PLUGINS='Neovim plugins (lazy.nvim)'

# ── macOS: bundle never opened ────────────────────────────────────────────

# $1 is the .app path.
msg_first_launch_hint() {
  ui_note 'an .app bundle never opened by LaunchServices has its'
  ui_note 'command-line binaries blocked. Open it once:'
  ui_note "  open -a \"$1\""
  ui_note 'confirm the macOS dialog, if one appears, and run again.'
}

# ── setup.sh ──────────────────────────────────────────────────────────────

# The --help / bad-argument text. Goes to stdout or to stderr depending on the
# caller, so it stays plain echo.
msg_setup_usage() {
  echo "Usage: bash scripts/setup.sh [--clean] [--yes]"
  echo
  echo "  --clean    resolve the conflicts the diagnosis finds (with a backup)"
  echo "  --yes, -y  never ask; without --clean, nothing existing is moved"
}

MSG_SETUP_UNSUPPORTED='System not supported by this script: %s'
MSG_SETUP_WINDOWS='On Windows, run:  .\scripts\bootstrap-windows.ps1'
MSG_SETUP_INTERRUPTED='interrupted — nothing was lost, running again is safe'
MSG_SETUP_RESUMING='carrying on inside WezTerm'

MSG_SETUP_STEP_DIAGNOSE='diagnose'
MSG_SETUP_STEP_DIAGNOSE_DESC='looks for what already exists here and would get in the way. Changes nothing.'
MSG_SETUP_NO_CONFLICTS='nothing conflicts'
MSG_SETUP_CONFLICTS='the ✖ items are skipped: the bootstrap never overwrites existing config'
MSG_SETUP_CLEAN_NOW='resolving now (--clean), with a backup in ~/.local/state/termstack/backup/'
MSG_SETUP_YES_NO_CLEAN='--yes without --clean: carrying on unresolved, nothing will be moved'
MSG_SETUP_ASK_RESOLVE='Resolve now? (moves what gets in the way, with a backup first)'
MSG_SETUP_ASK_CARRY_ON='Carry on without resolving?'
MSG_SETUP_CANCELLED='cancelled, nothing was changed'
MSG_SETUP_CANCELLED_NOTE='whenever you want:  bash scripts/setup.sh --clean'

MSG_SETUP_NO_TTY='no interactive terminal and no --yes: nothing was installed'
MSG_SETUP_NO_TTY_NOTE='for automation:  bash scripts/setup.sh --yes'
MSG_SETUP_STEP_INSTALL='install'
MSG_SETUP_STEP_INSTALL_DESC='tools, WezTerm, font, links, plugins. Minutes on a clean machine.'
MSG_SETUP_INSTALLED='installed'

MSG_SETUP_STEP_TERMINAL='terminal'
MSG_SETUP_STEP_TERMINAL_DESC='from here on a terminal with the Nerd Font active is required.'
MSG_SETUP_IN_WEZTERM='already inside WezTerm'
MSG_SETUP_UNCONFIRMED='could not confirm this terminal is WezTerm'
MSG_SETUP_UNCONFIRMED_NOTE='if the icons below come out broken, that is why'
MSG_SETUP_NO_WEZTERM='WezTerm not found — carrying on in this terminal'
MSG_SETUP_NO_WEZTERM_NOTE='glyphs may come out broken if the font is not active here'
MSG_SETUP_NO_TTY_HERE='no interactive terminal, carrying on right here'
MSG_SETUP_OPENING='opening a WezTerm window to carry on there'
MSG_SETUP_GUI_FAILED='could not open WezTerm — carry on there by hand:'
MSG_SETUP_GUI_FAILED_NOTE='bash %s/scripts/setup.sh --resumed'
MSG_SETUP_HANDED_OFF='carrying on in the WezTerm window'
MSG_SETUP_HANDED_OFF_NOTE='this window closes itself once the install finishes over there'
MSG_SETUP_HANDOFF_DONE='install finished in the WezTerm window — you can close this terminal'
MSG_SETUP_HANDOFF_TIMEOUT='30 min with no signal from the WezTerm window, wrapping up here'
MSG_SETUP_HANDOFF_TIMEOUT_NOTE='if the install over there is still running, it carries on normally'

MSG_SETUP_STEP_PROMPT='prompt'
MSG_SETUP_STEP_PROMPT_DESC='matching powerlevel10k to the font of this terminal.'
MSG_SETUP_P10K_OK='MODE=%s — already matches the font'
MSG_SETUP_P10K_MISMATCH='zsh/p10k.zsh is at MODE=%s with the Nerd Font installed'
MSG_SETUP_ASK_P10K="Run 'p10k configure' now?"
MSG_SETUP_P10K_DONE='configured — review and commit it:  git diff zsh/p10k.zsh'
MSG_SETUP_P10K_SKIPPED='skipped — preflight keeps warning until this is done'

# Why the wizard has to be re-run: a paragraph, so it is a function. The empty
# ui_note is the blank line separating the explanation from the reassurance.
msg_setup_p10k_why() {
  ui_note 'the p10k wizard does not detect fonts: it records the mode from YOUR'
  ui_note 'answers to its glyph questions. In a terminal without the font you'
  ui_note "answer \"I don't see it\" and it records the fallback — then the lock"
  ui_note 'becomes ∅ and jobs become ≡.'
  ui_note ''
  ui_note "takes about a minute, and rewrites the REPOSITORY's zsh/p10k.zsh, not"
  ui_note 'the ~/.p10k.zsh one: a single answer covers every machine.'
}

MSG_SETUP_STEP_VERIFY='verify'
MSG_SETUP_STEP_VERIFY_DESC='confirms all four layers really load.'
MSG_SETUP_DONE_IN='done in %sm%ss'
MSG_SETUP_NEXT_STEPS='Next steps'
MSG_SETUP_NEXT_SHELL='reload the shell, with mise on PATH'
MSG_SETUP_NEXT_ZELLIJ='press Ctrl+Space: the mode in the bar turns TMUX'
MSG_SETUP_NEXT_NVIM='LazyVim installs the rest on first use'
MSG_SETUP_CHECK_FAILED='the verification flagged the items above'
MSG_SETUP_CHECK_FAILED_NOTE1='most of it is usually existing config the bootstrap will not overwrite'
MSG_SETUP_CHECK_FAILED_NOTE2='to see and resolve:  bash scripts/setup.sh --clean'
MSG_SETUP_NEW_SHELL='opening a shell with the new environment…'

# ── preflight.sh ──────────────────────────────────────────────────────────

MSG_PRE_UNKNOWN_ARG='Unknown argument: %s'
MSG_PRE_ONE_OK='1 item in order'
MSG_PRE_N_OK='%s items in order'
MSG_PRE_BACKED_UP='backed up to %s'
MSG_PRE_FIX_BACKUP='back up %s'

MSG_PRE_GROUP_DUPS='Duplicate tools'
MSG_PRE_DUP_TOOL='%s installed by brew AND by mise'
MSG_PRE_DUP_WINNER='the one winning right now: %s'
MSG_PRE_DUP_STALE="brew's copy goes stale and shadows the mise one"
MSG_PRE_NO_DUPS='no tool installed by two managers'
MSG_PRE_CASK_BOTH='casks wezterm and wezterm@nightly installed together'
MSG_PRE_CASK_BOTH_NOTE='both write to /Applications/WezTerm.app'
MSG_PRE_CASK_STABLE='cask wezterm (stable) installed — that is the February 2024 build'
MSG_PRE_CASK_STABLE_NOTE="this repository's Brewfile uses wezterm@nightly"

MSG_PRE_GROUP_CONFIG='Existing configuration'
MSG_PRE_CFG_IS_REPO='%s is the repository itself'
MSG_PRE_CFG_LINKED='%s already points at the repository'
MSG_PRE_CFG_ELSEWHERE='%s links somewhere else: %s'
MSG_PRE_CFG_EXISTS='%s exists and is not a link — the bootstrap will not overwrite it'
MSG_PRE_CFG_FREE='%s is free'
MSG_PRE_CFG_LEGACY='%s exists and loses precedence to %s'
MSG_PRE_CFG_LEGACY_NOTE='it would stay on disk but never be read again'
MSG_PRE_ZELLIJ_LEGACY='old Zellij config in ~/Library/Application Support'
MSG_PRE_ZELLIJ_LEGACY_NOTE='ignored while ~/.config/zellij exists, but confusing when debugging'

MSG_PRE_GROUP_STALE='Stale state'
MSG_PRE_NVIM_STATE='Neovim state from another config: %s (%s)'
MSG_PRE_NVIM_STATE_NONE='no Neovim state from another distribution'
MSG_PRE_TMUX_OLD='old plugins in ~/.tmux/plugins (%s) are no longer used'
MSG_PRE_TMUX_OLD_NOTE='this repository uses ~/.config/tmux/plugins'
MSG_PRE_TMUX_IN_USE='%s still in use by the current config, kept'

MSG_PRE_GROUP_SHELL='Shell'
MSG_PRE_ZDOTDIR='ZDOTDIR=%s — zsh does not read ~/.zshrc'
MSG_PRE_ZDOTDIR_NOTE='the repository config would be written to ~/.zshrc and never loaded'
MSG_PRE_OWN_OMZ='%s loads oh-my-zsh/p10k on its own'
MSG_PRE_OWN_OMZ_NOTE1='that would be two compinit calls and two instant-prompt blocks'
MSG_PRE_OWN_OMZ_NOTE2='migration is manual: the recipe is in the marked block at the end of your rc'
MSG_PRE_STARSHIP='starship configured in ~/.zshrc — it fights powerlevel10k'
MSG_PRE_P10K_HOME='%s exists and will no longer be read (the repo uses zsh/p10k.zsh)'
MSG_PRE_P10K_HOME_NOTE="confusing when debugging 'I edited it and nothing changed'"
MSG_PRE_COMPINIT='compinit called %s time(s) outside the repository'
MSG_PRE_NVM='nvm in ~/.zshrc with mise installed'
MSG_PRE_NVM_NOTE='two Node managers on PATH, and sourcing nvm dominates startup'
MSG_PRE_NO_ZSHRC='no ~/.zshrc — clean machine, the bootstrap creates it'
MSG_PRE_P10K_MODE='zsh/p10k.zsh is at MODE=%s but the Nerd Font is installed'
MSG_PRE_P10K_MODE_NOTE="icons stay on the fallback; setup.sh offers to run 'p10k configure'"
MSG_PRE_FPATH_OK='fpath has no insecure directory'
MSG_PRE_COMPAUDIT='compaudit complained about permissions on fpath'
MSG_PRE_COMPAUDIT_NOTE='fix: compaudit | xargs chmod g-w,o-w'

MSG_PRE_GROUP_ENV='Environment'
MSG_PRE_NO_MISE='mise not installed yet — the bootstrap installs it'
MSG_PRE_MISE_ON_PATH='mise tools resolve on PATH'
MSG_PRE_MISE_INACTIVE='mise installed but not activated in this shell'
# shellcheck disable=SC2016  # $SHELL is literal, for the user to type
MSG_PRE_MISE_INACTIVE_NOTE='the tools exist and stay off PATH until you run: exec $SHELL'

MSG_PRE_ALL_CLEAR='Nothing to clean. You can run the bootstrap.'
# The two halves of the summary line, singular and plural. Separate keys and
# not one format: a language that pluralizes by more than an "s" needs both
# words whole, not a suffix glued on.
MSG_PRE_BLOCKER='blocker'
MSG_PRE_BLOCKERS='blockers'
MSG_PRE_WARNING='warning'
MSG_PRE_WARNINGS='warnings'
MSG_PRE_GROUP_PLAN='What --clean would do'
MSG_PRE_UNAPPLIED='nothing was changed. To apply:'
MSG_PRE_UNAPPLIED_NOTE='bash scripts/preflight.sh --clean'
MSG_PRE_ASK_APPLY='Apply?'
MSG_PRE_CANCELLED='cancelled, nothing was changed'
MSG_PRE_GROUP_APPLYING='Applying'
MSG_PRE_FIX_FAILED='failed, carrying on'
MSG_PRE_DONE='Done. Run the bootstrap for your system.'

# ── check.sh ──────────────────────────────────────────────────────────────

MSG_CHECK_ONE_OK='1 check passed'
MSG_CHECK_N_OK='%s checks passed'

# Both link checks, Zellij and Neovim, go through this pair.
MSG_CHECK_LINK_OK='%s -> repository'
MSG_CHECK_LINK_BAD='%s does not point at %s'

MSG_CHECK_GROUP_MACHINE='Machine'
MSG_CHECK_MDM='Mac managed by MDM — failures below may be company policy'
MSG_CHECK_NO_MDM='Mac without MDM'
MSG_CHECK_MISE_PRESENT='mise present (%s)'
# The two halves of the parenthesis above, chosen by whether the tools resolve.
MSG_CHECK_TOOLS_RESOLVE='tools resolve'
MSG_CHECK_NO_TOOLS='no tools'
MSG_CHECK_NO_MISE='mise not found — the CLI tools came from somewhere else'

MSG_CHECK_GROUP_WEZTERM='WezTerm'
MSG_CHECK_WEZTERM_MISSING='wezterm not found, skipping'
MSG_CHECK_WEZTERM_HUNG='wezterm hung (20s with no answer) — this is not the config'
MSG_CHECK_WEZTERM_HUNG_NOTE1='if it persists on an MDM-managed Mac, it may be company execution'
MSG_CHECK_WEZTERM_HUNG_NOTE2='policy. Check with IT before pushing further.'
MSG_CHECK_WEZTERM_LOADS='config loads (leader active)'
MSG_CHECK_WEZTERM_FALLBACK='config does NOT load — it fell back to the default. Run without the grep:'
MSG_CHECK_WEZTERM_FALLBACK_NOTE='%s --config-file %s/wezterm.lua show-keys'
MSG_CHECK_BINDING_OK='binding LEADER -> %s'
MSG_CHECK_BINDING_MISSING='binding LEADER -> %s missing'

MSG_CHECK_GROUP_TMUX='tmux'
MSG_CHECK_TMUX_MISSING='tmux not found, skipping'
MSG_CHECK_TMUX_CONF_ERR='tmux.conf complained: %s'
MSG_CHECK_TMUX_CONF_OK='tmux.conf loads without error'
MSG_CHECK_TMUX_PREFIX_OK='prefix is C-Space'
MSG_CHECK_TMUX_PREFIX_BAD="prefix is '%s', expected 'C-Space'"
MSG_CHECK_TMUX_THEME_OK='catppuccin loaded (@thm_* palette defined)'
MSG_CHECK_TMUX_THEME_BAD='catppuccin did not load — run the bootstrap, or prefix + I inside tmux'
MSG_CHECK_WIDGET_RAW='widget %s was not substituted (plugin did not load)'
MSG_CHECK_WIDGET_OK='widget %s active'
MSG_CHECK_WIDGET_MISSING='widget %s is not in the status bar'
MSG_CHECK_TMUX_BASE_OK='base-index is 1'
MSG_CHECK_TMUX_BASE_BAD="first window has index '%s', expected '1'"

MSG_CHECK_GROUP_ZELLIJ='Zellij'
MSG_CHECK_ZELLIJ_MISSING='zellij not found, skipping'
MSG_CHECK_ZELLIJ_KDL_OK='config.kdl is valid KDL'
MSG_CHECK_ZELLIJ_KDL_BAD='config.kdl invalid: %s'
MSG_CHECK_ZELLIJ_DIR_OK='CONFIG DIR points at ~/.config/zellij'
MSG_CHECK_ZELLIJ_DIR_BAD='wrong CONFIG DIR: %s'
MSG_CHECK_ZELLIJ_LOCKED_OK='default_mode locked (Ctrl+hjkl free for Neovim)'
MSG_CHECK_ZELLIJ_LOCKED_BAD='default_mode is not locked — Zellij will steal Ctrl+hjkl from Neovim'

MSG_CHECK_GROUP_NVIM='Neovim'
MSG_CHECK_NVIM_MISSING='nvim not found, skipping'
MSG_CHECK_NVIM_NAV_BAD='multiplexer navigation plugin in nvim/ — see DESIGN.md, Zellij section'
MSG_CHECK_NVIM_NAV_OK='no navigation plugin (Ctrl+hjkl arrives whole from the multiplexer)'

MSG_CHECK_GROUP_ZSH='zsh'
MSG_CHECK_OMZ_MISSING='%s missing or not a git repo — run the bootstrap'
MSG_CHECK_OMZ_OK='oh-my-zsh installed'
MSG_CHECK_PLUGIN_OK='plugin %s'
MSG_CHECK_PLUGIN_BAD='plugin %s missing or with the wrong file name'
MSG_CHECK_P10K_CLONED='powerlevel10k cloned'
MSG_CHECK_P10K_MISSING='powerlevel10k missing'
MSG_CHECK_HL_LAST_OK='zsh-syntax-highlighting is last in the array'
MSG_CHECK_HL_LAST_BAD="last plugin is '%s' — syntax-highlighting has to be last"
MSG_CHECK_ZSH_MISSING='zsh not found, skipping'
MSG_CHECK_ZSH_HUNG='zsh -i hung (25s) — the repository config is stuck'
MSG_CHECK_OMZ_COMPLAINED='omz complained: %s'
MSG_CHECK_THEME_OK='ZSH_THEME is powerlevel10k'
MSG_CHECK_THEME_BAD='wrong ZSH_THEME, or omz did not load'
MSG_CHECK_P10K_LOADED='powerlevel10k loaded'
MSG_CHECK_P10K_NOT_LOADED='powerlevel10k did not load'
MSG_CHECK_HL_OK='syntax-highlighting active'
MSG_CHECK_HL_BAD='syntax-highlighting did not load'
MSG_CHECK_CATPPUCCIN_OK='catppuccin applied (the overrides won)'
MSG_CHECK_CATPPUCCIN_BAD='catppuccin not applied: %s'

MSG_CHECK_GROUP_REPO='Repository'
MSG_CHECK_CUSTOM_IGNORED='zsh/custom ignored by git'
MSG_CHECK_CUSTOM_NOT_IGNORED='zsh/custom NOT ignored — third-party clones would enter the repository'
MSG_CHECK_MACHINE_IGNORED='machine.lua is ignored by git'
MSG_CHECK_MACHINE_NOT_IGNORED='machine.lua is NOT ignored — risk of leaking local config'
MSG_CHECK_MACHINE_TRACKED='machine.lua is tracked by git — remove it with: git rm --cached machine.lua'
MSG_CHECK_MACHINE_UNTRACKED='machine.lua is not tracked'
MSG_CHECK_LOCK_ABSENT='%s does not exist yet (created on first Neovim use)'
MSG_CHECK_LOCK_TRACKED='%s tracked by git'
MSG_CHECK_LOCK_UNTRACKED='%s NOT tracked — the machines will drift apart. git add %s'

MSG_CHECK_ALL_GOOD='All good.'
MSG_CHECK_ONE_FAILED='1 check failed.'
MSG_CHECK_N_FAILED='%s checks failed.'

# ── update.sh ─────────────────────────────────────────────────────────────

MSG_UPD_NO_SNAPSHOT='no update snapshot to restore'
MSG_UPD_GROUP_ROLLBACK='Rollback'
MSG_UPD_RESTORING='restoring %s'
MSG_UPD_REPO_RESET='repository → %s'
MSG_UPD_DIRTY='dirty working tree: the repository was NOT reverted'
MSG_UPD_DIRTY_NOTE='your modified files were left as they were. By hand:'
# The three %s are the repository path, twice, and the revision.
MSG_UPD_DIRTY_CMD='git -C "%s" stash && git -C "%s" reset --hard %s'
MSG_UPD_MACHINE_RESTORED='machine.lua restored'
MSG_UPD_NVIM_RESTORED='nvim/%s restored'

# Why a rollback does not downgrade the tools. A paragraph, so it is a
# function. $1 is the path of the version list inside the snapshot.
msg_upd_versions_note() {
  ui_note ''
  ui_note 'tool versions are NOT reverted automatically:'
  ui_note 'a downgrade costs a download and is rarely the cause. If you need'
  ui_note 'them, the previous versions are in:'
  ui_note "$1"
}

MSG_UPD_GROUP_SNAPSHOT='Snapshot'
MSG_UPD_SNAPSHOT_AT='snapshot at %s'

MSG_UPD_GROUP_REPO='Repository'
MSG_UPD_PULL='git pull'
MSG_UPD_UP_TO_DATE='already up to date'
MSG_UPD_PULLED='%s → %s'
MSG_UPD_OFFLINE='offline: skipping every network step'

MSG_UPD_GROUP_LINKS='Config links'

MSG_UPD_GROUP_TOOLS='Tools'
MSG_UPD_MISE_UPGRADE='mise upgrade'
MSG_UPD_BREW='Homebrew'

MSG_UPD_GROUP_PLUGINS='Plugins'
MSG_UPD_ZSH_REPOS='oh-my-zsh, powerlevel10k and the zsh plugins'
MSG_UPD_ZSH_FAILED='a zsh repository failed'
MSG_UPD_NVIM_UNCHANGED='nvim/ unchanged, skipping the Neovim plugins'

MSG_UPD_CHECK_FAILED='Verification failed after the update.'
MSG_UPD_ROLLING_BACK='rolling back to the snapshot.'
MSG_UPD_GROUP_AFTER='State after the rollback'
MSG_UPD_RESTORED='Environment restored. What came in the pull was left out.'
MSG_UPD_SNAPSHOT_KEPT='snapshot kept at: %s'
MSG_UPD_ROLLBACK_NOOP='The rollback did not help — the failure predates the update.'
MSG_UPD_SNAPSHOT_STILL='snapshot at: %s'

# ── bootstrap-macos.sh ────────────────────────────────────────────────────

MSG_BOOT_NOT_MACOS='This script must be run on macOS.'

MSG_BOOT_GROUP_BEFORE='Before you start'
MSG_BOOT_ENTRY_POINT='the entry point is setup.sh — it asks before touching anything'
MSG_BOOT_ENTRY_POINT_NOTE='that already exists, and tunes the prompt at the end:'
MSG_BOOT_ENTRY_POINT_CMD='bash "%s/scripts/setup.sh"'
MSG_BOOT_PREFLIGHT_FIX='to resolve the items above before installing:'
MSG_BOOT_PREFLIGHT_FIX_CMD='bash "%s/scripts/preflight.sh" --clean'
MSG_BOOT_CARRY_ON='carrying on with the bootstrap — nothing existing gets overwritten.'

MSG_BOOT_GROUP_CLI='Command-line tools'

MSG_BOOT_GROUP_WEZTERM='WezTerm and font'
MSG_BOOT_BREW_BUNDLE='brew bundle (WezTerm nightly + JetBrainsMono Nerd Font)'
MSG_BOOT_OPEN_ONCE='opening WezTerm once (registers the bundle with LaunchServices)'
MSG_BOOT_NO_BREW='Homebrew not found — WezTerm has to be downloaded by hand'

# Where to get WezTerm by hand. A block, so the release URL and the file name
# keep their indentation under the two lines of text.
msg_boot_no_brew_hint() {
  ui_note 'the CLI tools and the font were installed without it already.'
  ui_note 'WezTerm nightly (no sudo, unzip into ~/Applications):'
  ui_note '  https://github.com/wezterm/wezterm/releases/tag/nightly'
  ui_note '  file WezTerm-macos-nightly.zip'
}

MSG_BOOT_GROUP_LINKS='Config links'

MSG_BOOT_GROUP_PLUGINS='Plugins'
MSG_BOOT_ZSH_REPOS='oh-my-zsh, powerlevel10k and the zsh plugins'
MSG_BOOT_ZSH_FAILED='a zsh repository failed'

MSG_BOOT_GROUP_DONE='Done'

# The epilogue of a bootstrap run on its own, without setup.sh. A paragraph
# with blank lines, so it is a function. $1 is the repository path.
msg_boot_done() {
  ui_note "reopen the shell (or: exec \$SHELL) so mise lands on PATH."
  ui_note ''
  ui_note 'one manual test that cannot be automated: open Zellij and press'
  ui_note 'Ctrl+Space. The mode indicator in the bar has to turn TMUX. If it'
  ui_note 'does not, your terminal cannot tell that combination apart — change'
  ui_note "the bind in zellij/config.kdl (Zellij's own default is Ctrl+b)."
  ui_note ''
  ui_note 'verify everything with:'
  ui_note "bash \"$1/scripts/check.sh\""
}

# ── bootstrap-linux.sh ────────────────────────────────────────────────────
#
# The preamble, the group titles and the plugin lines are the same text as the
# macOS bootstrap, so they reuse the MSG_BOOT_* keys above. Only what is
# specific to Linux lives here.

MSG_BOOT_NOT_LINUX='This script must be run on Linux.'

MSG_BOOT_WSL_SKIP='WSL detected: skipping WezTerm and font (use the Windows ones)'
MSG_BOOT_WEZTERM_PRESENT='WezTerm already installed (%s)'
MSG_BOOT_PACMAN='installing WezTerm through pacman'
MSG_BOOT_PACMAN_NOTE='for the nightly: paru -S wezterm-git'
MSG_BOOT_APT='installing WezTerm through the official apt repository'
MSG_BOOT_COPR='installing WezTerm through copr (nightly)'
MSG_BOOT_ZYPPER='installing WezTerm through zypper'
MSG_BOOT_NO_DISTRO='unrecognized distribution for installing WezTerm'
MSG_BOOT_APPIMAGE='AppImage: https://github.com/wezterm/wezterm/releases'

# The epilogue of a Linux bootstrap run on its own. Same shape as
# msg_boot_done, without the paragraph about changing the Zellij bind.
# $1 is the repository path.
msg_boot_linux_done() {
  ui_note "reopen the shell (or: exec \$SHELL) so mise lands on PATH."
  ui_note ''
  ui_note 'one manual test that cannot be automated: open Zellij and press'
  ui_note 'Ctrl+Space. The mode indicator in the bar has to turn TMUX.'
  ui_note ''
  ui_note 'verify everything with:'
  ui_note "bash \"$1/scripts/check.sh\""
}

# ── The cheatsheet ────────────────────────────────────────────────────────

# A whole screen rather than a line, so it is a function. It reads the UI_*
# palette directly, which means a translation only has to deal with words.
#
# Hard limit: 78 columns of VISIBLE text. At the end of setup this may land in
# an 80-column Terminal.app, and a line wrapped mid-word is worse than an
# extra line. A test enforces it.
msg_cheatsheet() {
  local b=$UI_B c=$UI_AZ d=$UI_DIM r=$UI_R rule
  rule="$(printf '%*s' 74 '' | tr ' ' '─')"

  cat <<TXT

  ${c}${rule}${r}
  ${b}The stack, in four layers${r}
  WezTerm ${b}Ctrl+a${r}   Zellij ${b}Ctrl+Space${r}   tmux ${d}same (backup)${r}   LazyVim ${b}Space${r}
  ${d}Ctrl+h/j/k/l always belongs to Neovim — that is why Zellij starts locked.${r}
  ${c}${rule}${r}

  ${b}Prefix, then${r} ${d}— WezTerm and Zellij, same keys${r}
    ${b}|${r} ${b}-${r} split   ${b}h j k l${r} focus   ${b}x${r} close   ${b}z${r} zoom   ${b}c n p${r} tabs   ${b}[${r} copy
    ${d}WezTerm only${r}  ${b}H J K L${r} resize   ${b}1${r}…${b}9${r} tab N   ${b}space${r} launcher
                  ${b}Ctrl+a${r} again sends a literal Ctrl+a to the shell
    ${d}Zellij only${r}   ${b}f${r} floating   ${b}s${r} sessions   ${b}w${r} manager   ${b}Esc${r} lock
                  ${d}zj -n dev opens nvim+terminal · zj attach NAME · zj ls${r}

  ${b}LazyVim — Space, then${r}
    ${b}space${r} find file   ${b}/${r} grep   ${b},${r} buffers   ${b}e${r} file tree   ${b}f r${r} recent
    ${b}g g${r} lazygit   ${b}b b${r} last buffer   ${b}c d${r} diagnostic   ${b}q q${r} quit   ${b}l${r} :Lazy
    ${b}|${r} ${b}-${r} split window   ${b}Ctrl+h/j/k/l${r} windows   ${b}Ctrl+/${r} terminal
    ${d}:LazyExtras toggles extras   :LazyHealth runs diagnostics${r}

  ${b}Shell${r}
    ${b}v${r} nvim   ${b}lg${r} lazygit   ${b}zj${r} zellij   ${b}z DIR${r} jump ${d}(zoxide)${r}   ${b}gst ga gcm gp${r} ${d}git${r}
    ${b}Ctrl+R${r} fuzzy history   ${b}Ctrl+T${r} find file   ${b}↑ ↓${r} prefix   ${b}→${r} accept hint

  ${b}Forgot a key?${r}
    ${b}Ctrl+a ?${r} ${d}or${r} ${b}Ctrl+Space ?${r}   this sheet ${d}(any key closes it)${r}
    ${b}Ctrl+Shift+P${r} WezTerm palette ${d}(search)${r}   ${b}prefix ?${r} tmux keys
    ${b}Space${r} and wait: LazyVim which-key ${d}— these three read the live config${r}

  ${b}Maintenance${r} ${d}— local tweaks outside git: machine.lua, ~/.zshrc.local${r}
    ${b}setup.sh${r} install ${d}(--clean resolves)${r}   ${b}update.sh${r} snapshot + rollback
    ${b}check.sh${r} verify layers   ${b}preflight.sh${r} conflicts   ${b}stack${r} show this again

TXT
}
