# Repository plan: decisions and rationale

This document records **why** the repository is the way it is. The step-by-step usage guide lives in the [README](README.md).

## Goal

One WezTerm configuration, reusable across five scenarios:

- Work MacBook
- Personal MacBook
- Personal Windows PC
- Ubuntu/Debian running inside WSL
- Native Linux

The shape: a shared, version-controlled Lua base, plus a local `machine.lua` that Git ignores, for the per-machine differences.

---

## Architecture

```text
Application installed separately on each system
                  +
repository cloned into ~/.config/wezterm
                  +
shared Lua configuration
                  +
local, ignored machine.lua
```

WezTerm looks for the config file in this order — and the path `~/.config/wezterm/wezterm.lua` **works on all three systems, Windows included** (`C:\Users\you\.config\wezterm\wezterm.lua`):

1. `--config-file` on the command line
2. `$WEZTERM_CONFIG_FILE`
3. Windows only: `wezterm.lua` next to `wezterm.exe` (thumb-drive mode)
4. `$XDG_CONFIG_HOME/wezterm/wezterm.lua`
5. `$HOME/.config/wezterm/wezterm.lua`
6. `$HOME/.wezterm.lua`

That same directory goes into Lua's `package.path`, which is what makes `require('config.appearance')` and `require('machine')` work without any path hack.

## Structure

```text
termstack/
├── wezterm.lua
├── config/
│   ├── appearance.lua      colors + window + font
│   ├── keys.lua            leader CTRL+a, tmux style
│   └── platform.lua        per-OS tweaks + Windows launch_menu
├── tmux/
│   └── tmux.conf           C-Space prefix, catppuccin, widgets
├── scripts/
│   ├── _common.sh          helpers shared by the bootstraps
│   ├── bootstrap-macos.sh
│   ├── bootstrap-linux.sh
│   ├── bootstrap-windows.ps1
│   └── check.sh            verification of both configs
├── machine.example.lua
├── Brewfile
├── .gitattributes
├── .gitignore
└── README.md
```

### Why three modules and not seven

An earlier version of this plan called for `appearance`, `fonts`, `keybindings`, `launch_menu`, `platform`, `status` and `workspace`, plus six scripts. What was cut, and why:

- `fonts.lua` → merged into `appearance.lua`. It is ten lines that you always read together with the colors.
- `launch_menu.lua` → merged into `platform.lua`. The launch menu only exists on Windows; it was a file whose first statement was "if this is not Windows, return".
- `status.lua`, `workspace.lua` → deleted. They had no content. A `require` of a non-existent module is a fatal error in WezTerm: the entire config falls back to the default.
- `update-macos.sh`, `update-linux.sh`, `update-windows.ps1` → deleted. All three were `git pull --ff-only`, which is already in the README.
- `templates/machine.example.lua` → moved to the root. A directory for a single file.

Every extra file is one more `require` to keep in sync across five machines. Split when one of the files gets too big to read in one go, not before.

---

## Fixes over the original plan

The overall design of the previous plan was right, but the code in it did not run. Verified against the official documentation in July 2026:

| # | Where | Problem |
|---|---|---|
| 1 | `wezterm.lua` | `require` of `keybindings`, `status` and `workspace`, three files the plan never defined. Missing module = fatal error, the whole config becomes the default |
| 2 | `bootstrap-windows.ps1` | `Set-StrictMode -Version Latest` combined with `$IsWindows`: that variable does not exist in Windows PowerShell 5.1, which is what "Run with PowerShell" defaults to. The script crashed on its own platform guard |
| 3 | `bootstrap-linux.sh` | The `ubuntu\|debian` and `fedora\|rhel` branches were `echo` with no command at all. The script finished successfully without having installed anything |
| 4 | both bootstraps | `exit 0` right at the start when WezTerm was already installed, skipping the Brewfile and the creation of `machine.lua` |
| 5 | Linux `machine.lua` | `enable_wayland = true` does nothing: it has been the default since version `20220624-141144-bd1b7c5d` |
| 6 | repository | Without `.gitattributes`, a clone on Windows with `core.autocrlf=true` writes CRLF into the `.sh` files; running them under WSL fails with `bad interpreter: /usr/bin/env bash^M` |
| 7 | `pcall(require, 'machine')` | If `machine.lua` existed but had a syntax error, the `pcall` swallowed it silently: the config came up without the overrides and without any warning |
| 8 | `platform.lua` | `default_prog = {'/bin/zsh','-l'}` hardcodes the shell path — it breaks for anyone using zsh from brew, fish or nix. And on Windows `default_prog` collides with `default_domain` pointing at WSL ([wezterm#6147](https://github.com/wezterm/wezterm/issues/6147)) |

And three gaps:

- **`config:set_strict_mode(true)`** was missing. It is the whole reason `config_builder()` exists: without it, an invalid option is only a warning and the config comes up silently wrong. It counts double here, because merging `machine.lua` writes arbitrary keys into the config.
- **No keybindings at all.** That is the main reason to keep your own terminal config in the first place.
- **No validation step.** Without one, a broken config only shows up on the next machine.

### Decisions that came out of those fixes

**`machine.lua` accepts either a table or a function.** A table does a shallow merge of keys, which covers `font_size` and `window_background_opacity`. But a shallow merge does not let you add a keybinding — only replace the whole list. Whoever returns a function gets `(config, wezterm)` and does `table.insert(config.keys, ...)`. Both forms cost eight lines in `wezterm.lua`.

**Missing is normal, broken is not.** The `pcall` stays, but the error is only swallowed when the message is literally `module 'machine' not found`. Any other error is re-raised.

**No `default_prog`.** WezTerm already reads the shell from `/etc/passwd`. On Windows, `default_domain` in `machine.lua` is what decides; the `launch_menu` covers the one-off cases and carries `powershell.exe` as a fallback for anyone without PowerShell 7.

**The font goes into the bootstrap.** `cask "font-jetbrains-mono-nerd-font"` in the Brewfile and `DEVCOM.JetBrainsMonoNerdFont` in winget. On Linux it stays manual: there is no Nerd Font package with the same name across distros, and automating that would be an entire `case` for one download. The script detects the absence and warns.

**The Brewfile only carries what belongs to WezTerm.** `git`, `fzf`, `ripgrep` and `starship` belong to your shell setup. If this Brewfile turns into the inventory of your whole environment, it stops being able to run on its own on the work Mac.

---

## Strategy for WSL

On Windows, you install the **Windows** WezTerm and use it to open the WSL distribution. You do not install WezTerm's GUI inside Ubuntu.

Practical consequence: the font is installed on Windows, not in the distro. The one doing the rendering is the Windows WezTerm.

To find the exact domain name:

```powershell
wsl --list --verbose
```

The domain name is `WSL:` plus the distro name. To set it as the default:

```lua
return {
  default_domain = 'WSL:Ubuntu',
}
```

This lives in the personal PC's `machine.lua`, not in the shared base — the Macs have no WSL domain at all.

---

## Zellij

Zellij is the main multiplexer; tmux stays installed and configured as the alternative. They never run together.

### The decision that settles everything else: it starts locked

```kdl
default_mode "locked"
```

In locked mode Zellij captures no key at all beyond the mode-entry one. Every `Ctrl+*` and `Alt+*` in `default.kdl` lives inside `shared_except "locked"` blocks, so in locked mode they simply do not exist.

The consequence is the entire point: **`Ctrl+h/j/k/l` arrives intact in Neovim**, no plugin, no subprocess per keystroke, no "is this pane running nvim?" detection.

The cost, stated plainly: you do not jump from a Neovim split straight into a neighboring Zellij pane with the same key. Switching multiplexer panes is `Ctrl+Space h`. One extra key on an action far less frequent than navigating splits.

### Why no navigation plugin

Every candidate is either broken or stalled (survey from July 2026):

| Plugin | State |
|---|---|
| `hiasr/vim-zellij-navigator` | detection broken by design; issues #26 and #36 open with no fix |
| `fresh2dev/zellij-autolock` | dead; issue #18 open: "Fails to trigger/detect commands in Zellij 0.44.0" |
| `swaits/zellij-nav.nvim` | stalled, and the path its README documents is the dead autolock |
| `mrjones2014/smart-splits.nvim` | alive, but the Zellij path **delegates** to vim-zellij-navigator |

The root cause: the navigator reads `running_command` from `ListClients` to know whether the pane is running nvim. Zellij ≥ 0.42.2 flattens editor panes to `Run::EditFile` and synthesizes the string from `$EDITOR`, or returns `"N/A"`. Result: the key moves the Zellij pane instead of forwarding to Neovim.

`check.sh` fails if any of them shows up in `nvim/` — that is a regression, not an improvement.

### Prefix shared with tmux

`Ctrl+Space` in both. This is not confusion: they never run at the same time, the sub-keys are identical, and giving Zellij a different prefix would spend a second key out of the same scarce budget — stealing one more from Neovim and gaining nothing.

To know which one you are in, look at the bar: tmux shows cpu/ram/battery, Zellij shows the mode indicator.

### KDL details that cost time

- **`clear-defaults` is per mode, never global.** The global one also wipes the `shared_except` bindings that give you entry into every mode, and you end up with no way out of wherever you are.
- **`unbind` has to be scoped.** `Ctrl+b` is bound in four places in `default.kdl`; a global unbind kills page-up in the scroll and search modes.
- **Every action in tmux mode ends in `SwitchToMode "Locked"`**, never `"Normal"` — in Normal, Zellij re-enables its capture of `Ctrl+p/n/t/s/o`.
- **Do not set `copy_command`.** The default is OSC 52, the only thing that survives SSH when the session is on a remote host. WezTerm supports OSC 52 natively.
- **Do not set only one of `theme_dark`/`theme_light`** — that makes Zellij silently ignore both.
- **`catppuccin-mocha` ships built in**, no `theme_dir` needed.

### What was left out

- **`zjstatus`** — good, but it is a remote `.wasm` with a cache versioned per Zellij release: every upgrade forces a re-download, and the first offline boot after an upgrade has no bar. The built-in `compact-bar` is already colored by the theme.
- **`layouts/`** — `default_layout "compact"` uses the built-in layout.

### What was verified by hand

**`Ctrl+h/j/k/l` arrives intact in Neovim inside a Zellij pane — confirmed.** With Neovim split via `:vsplit` inside a pane, the keys navigate between Neovim's windows; focus does not escape to the Zellij panes.

That is the validation of the entire design: `default_mode "locked"` replaces the navigation plugin, and replaces it well — the two plugins that would do that job are broken today.

**`Ctrl+Space` reaches Zellij as a distinct key — confirmed in WezTerm.** The mode in the bar goes from `locked` to `TMUX`.

This matters because it was the biggest risk in the design: `Ctrl+Space` historically resolves to NUL in several terminals, and the research found no source testing that specific combination. If it had failed, the prefix would have had to change on all five machines. It is not automatable — no test can simulate a key arriving at the terminal.

If it ever fails in another terminal, the fallback is `Ctrl+b` (Zellij's default) in `zellij/config.kdl`, and the emergency exit for getting into Zellij is `Ctrl+g`, which toggles locked ↔ normal and was left intact on purpose.

### The uncertainty that was left — resolved

**`Write 0` as "prefix prefix"** — the line that sends a literal `Ctrl+Space` onward, for when there is a nested Zellij or ssh. It was a deduction from the ASCII convention (NUL), with no documentation anywhere. **Verified**: in a real Zellij 0.44.3 session, with a pane running `dd bs=1` and the keys injected through the pty, the pane's program received exactly `A \x00 B` — the `A` passed straight through in locked mode, the first `Ctrl+Space` was captured (mode switch, nothing reaches the pane) and the second delivered the literal NUL byte. That is the behavior of tmux's `send-prefix`, as designed.

A test detail worth recording: the first harness used `cat > log` and the log came out empty — not because the key was not arriving, but because cat's stdio holds the bytes in a buffer and the pane's tty, in canonical mode, holds the line until the `\n`. The echo on screen (`A^@B`) is what delivered the truth before the log did.

---

## Neovim and LazyVim

On the terminal side the essentials are already settled: Nerd Font installed by the bootstrap, true color in WezTerm by default and in tmux via `terminal-overrides` with `RGB`, `focus-events on` so that `:autoread` works, and `escape-time 10` so ESC does not feel like a freeze. Both prefixes are prefixed, so `LEADER h/j/k/l` and `prefix h/j/k/l` do not compete with the `<C-h/j/k/l>` that LazyVim uses to move between windows.

What is still outstanding, in order of annoyance:

**`CTRL+a` is `increment` in Vim.** Choosing `CTRL+a` as the terminal leader takes that key away from Neovim. The way out already exists — `LEADER` `CTRL+a` sends a literal `CTRL+a` — but it is one extra key for a frequent operation if you edit numbers. If it bothers you, `CTRL+Space` is the alternative leader that conflicts with neither Vim nor tmux: one line in `config/keys.lua`.

**Undercurl on diagnostics** requires `term = 'wezterm'`, which requires WezTerm's terminfo installed **on the machine where Neovim runs**. That includes every WSL distro and every host reached over ssh; with the terminfo missing, the session comes up corrupted. That is why it is commented-out opt-in in `machine.example.lua`, with the `tic` command right there, and does not go into the shared base.

**Seamless navigation between WezTerm panes and Neovim splits** is what [`smart-splits.nvim`](https://github.com/mrjones2014/smart-splits.nvim) solves: `CTRL+h/j/k/l` crosses the boundary between the Neovim split and the terminal pane without you thinking about which of the two has focus. On the WezTerm side it is a plugin, and plugins are out of scope for now (see below). It is the number one candidate to be the first plugin, when there is one.

### Vendored in `nvim/`, not cloned

`LazyVim/starter` is a *template*, not an upstream: the official installation step is literally `rm -rf ~/.config/nvim/.git`, and it has been frozen since 2024-12-11. All the evolution lives in `LazyVim/LazyVim`, which is a normal dependency managed by lazy.nvim. There is nothing to track.

The symlink `~/.config/nvim -> nvim/` is mandatory because `NVIM_APPNAME` only accepts a name or a relative path, never an absolute one. With it, `stdpath('config')` is still `~/.config/nvim` and the two state files land inside the repository on their own.

| File | Version-controlled? | Why |
|---|---|---|
| `nvim/lazy-lock.json` | **Yes** | It is the only thing that makes the five machines have the same plugin SHAs |
| `nvim/lazyvim.json` | **Yes** | State of the extras enabled via `:LazyExtras`; without it the other machine does not get your extras |
| `nvim/init.lua`, `lua/**` | Yes | — |

Every `:Lazy update` and every toggle in `:LazyExtras` leaves the repository dirty. That is the desired behavior, but it means committing — otherwise the lockfile becomes permanent noise in `git status`.

Two lazy.nvim-specific traps, which `scripts/_common.sh` already works around:

- **`Lazy! sync` rewrites the lockfile** (sync = install + clean + *update*), destroying the reproducibility the lockfile is supposed to give. The right thing in a script is `install` and then `restore` — in that order, because `restore` filters by already-installed plugin and cannot install what is missing.
- **`nvim --headless "+Lazy! ..." +qa` exits with 0 even when every plugin fails to clone.** lazy.nvim's only `os.exit(1)` is in the test runner. Read the output; do not trust the return code.

**LazyVim's dependencies** (`lazygit`, `ripgrep`, `fd`) come in through mise along with everything else, so they arrive resolved on all five machines.

**Theme:** catppuccin mocha declared as a plugin spec in `nvim/lua/plugins/colorscheme.lua`, not as an extra in `lazyvim.json`. Mixing the two models makes `:LazyExtras` refuse to manage whatever was imported by hand.

---

## Installation: always the newest version

**Stable WezTerm is two and a half years old.** `20240203-110809-5046fc22`, from February 2024, and it is the same build in the cask, in winget, in scoop, in Arch `extra` and in apt.fury.io. "Up-to-date WezTerm" means nightly, on every platform — there is no alternative.

Everything else goes through `mise`: prebuilt binary, installed into `~/.local`, without sudo, with the same command on all five machines. That is what solves the work Mac, where Homebrew requires sudo for the default prefix (and installing into `~/homebrew` would make every formula compile from source).

The split: **mise for CLI, native manager only for the GUI app and the font.** The `Brewfile` ends up with two lines.

Verified traps:

- **`brew upgrade` never updates `wezterm@nightly`**: the cask has `version :latest`, brew cannot compare versions and silently skips it. You think you are on nightly and you are on a build from months ago. That is why `update.sh` uses `--greedy-latest`.
- **`--no-quarantine` was removed in Homebrew 6.0.0** and is a fatal error today. WezTerm's official documentation still recommends that command.
- **An `.app` bundle never opened by LaunchServices blocks its command-line binaries.** Measured on this machine: `wezterm --version` hung in dyld indefinitely — no error, no stdout, no timeout — and the kernel log showed `AppleSystemPolicy: Security policy would not allow process`. The same binary copied outside the bundle ran immediately, even carrying `com.apple.quarantine`. In other words: it is not the quarantine, it is the bundle never having gone through LaunchServices. `open -a` once fixes it, and the bootstrap does that.
- **`fd` has three behaviors**: on Debian/Ubuntu the package is `fd-find` and the binary is `fdfind`; on Fedora the package is `fd-find` and the binary is `fd`. Through mise it is `fd` everywhere.

---

## Cleanup before installing

`scripts/preflight.sh` looks for what already exists on the machine and is going to get in the way. By default it only diagnoses; `--clean` resolves it, with a backup first.

It is not an "uninstall everything and reinstall". What breaks is almost never the tool being installed — it is **which copy wins in `PATH`** and **which config wins in the precedence order**. Removing blindly takes away what you use today and fixes neither of those two.

What it detects, and why each one matters:

| Conflict | Effect |
|---|---|
| Tool installed by brew **and** mise | `PATH` decides, and it is almost never the newer one. Happened with tmux on this machine: brew 3.7b winning over mise |
| Casks `wezterm` and `wezterm@nightly` together | Both write to `/Applications/WezTerm.app` |
| `~/.config/<x>` exists and is not a link | That config is never linked, and the bootstrap does not overwrite |
| `~/.tmux.conf` with `~/.config/tmux` on the way | The old one stays on disk and is never read again |
| Zellij config in `~/Library/Application Support` | Ignored when `~/.config/zellij` exists — the classic "I edited it and nothing changed" |
| State from another Neovim distribution | LazyVim on top of AstroNvim/NvChad state gives an obscure plugin error |
| Orphaned `~/.tmux/plugins` | It only becomes garbage after `~/.config/tmux` takes over; before that it is the installation in use |
| mise installed without shell activation | The tools exist and do not show up in `PATH` |

The bootstrap calls preflight and **does not abort**: it degrades on its own, leaves alone whatever is busy, and warns. The one who decides to clean is the user.

---

## Shell

The repository neither changes nor installs a shell, and it should not. **Nothing in the stack depends on it**: Zellij uses `$SHELL` for `default_shell`, WezTerm reads the shell from `passwd`.

What it does add to `~/.zshrc`/`~/.bashrc` is a marked block with two mandatory lines: mise's activation (without it the tools do not enter `PATH`) and `EDITOR`/`VISUAL`. `EDITOR` is not a preference — Zellij resolves the scrollback editor exactly once, at startup, and falls back to the literal `vi` if the variable is not set beforehand. That is why `config.kdl` also declares `scrollback_editor "nvim"`: version-controlled, valid on all five machines, and independent of the shell's load order.

Why not unify the shell across the machines:

- **fish and nushell are not in macOS's `/etc/shells`.** Adding them requires `sudo` — blocked precisely on the work Mac, which is where the uniformity would be worth the most.
- **fish is not POSIX**, and the friction lands exactly where this repository lives: `source` of a snippet, an installation one-liner, `sh -c` fired off by a Neovim plugin.
- mise activates in seven shells, but only bash, zsh and fish have full support; nushell and PowerShell have no shell alias.

Conclusion: zsh on macOS, bash on Linux/WSL, each one's defaults.

---

## Updating

One command on the target machine: `bash scripts/update.sh`.

The order is local before network, cheap before expensive, verification at the end. And before all of it, a **snapshot**.

### Snapshot and rollback

The snapshot keeps the repository's SHA, the `machine.lua` (which is not version-controlled and would be gone forever), the `lazy-lock.json`, the `lazyvim.json`, the tool versions and where each link pointed.

If the final verification fails, the script restores the snapshot on its own and runs the verification again, to say whether the rollback fixed it or whether the failure was already there before. A machine does not end up broken because a bad commit arrived through `git pull`.

Tool versions are not rolled back automatically: a downgrade costs a download and is rarely the cause. They are recorded in the snapshot so you can re-pin by hand.

### Git hook: no

Three reasons:

1. **`core.hooksPath` is not inherited by `git clone`** — it is local config, not version-controlled. The hook file travels with the repository, the pointer does not. The bootstrap would have to configure it anyway, so the hook never self-installs.
2. **`post-merge` does not fire on `git pull --rebase` with a real divergence** — it fires `post-rewrite`. Since `pull.rebase=true` is a common config, the hook would fail silently exactly where it matters most.
3. **A version-controlled hook means every `git pull` runs code from the repository**, and a slow hook turns `git pull` into an unexplained wait.

### Pinned tmux plugins never update with `git pull`

In a `--depth 1 --branch <tag>` clone, `git pull` answers "Already up to date." with exit 0 forever. Only a re-clone changes version — and only when the `#ref` in `tmux.conf` changes. The `@plugin` line is the lockfile.

A detail that cost one round: the version comparison uses `git tag --points-at HEAD`, not `git describe --exact-match`. `catppuccin/tmux` has four tags on the same commit (`latest`, `v2`, `v2.3`, `v2.3.0`) and `describe` returns only one of them, almost never the pinned one — which made the script re-clone on every run.

And no `tpm/bin/update_plugins`: it always returns exit 0 (the update runs in a subshell and the failure flag never escapes), it resolves the directory by reading from an already-running tmux server, and `clean_plugins` compares by substring.

---

## Work Mac and MDM

The scripts do not use `sudo` on macOS, do not install Homebrew, do not remove quarantine and do not work around MDM — on purpose.

On a managed machine, four things can block you, and none of them has a workaround from the script:

1. **Gatekeeper policy** may refuse WezTerm without showing a dialog, and then the bootstrap's `open -a` does not fix it.
2. **A security agent** (CrowdStrike, SentinelOne, Jamf Protect) may block a binary downloaded into `~/.local/bin` — exactly what mise does. This is the biggest risk.
3. **A proxy with TLS inspection** breaks mise's and git's downloads with a certificate error.
4. **Homebrew** does not install without sudo into the default prefix.

`check.sh` detects MDM and warns, so that a failure becomes a diagnosis instead of a mystery. If WezTerm is blocked, Zellij, LazyVim and tmux keep working inside whatever terminal the company allows; only the WezTerm config goes unused.

---

## tmux

tmux goes into the same repository because both configurations are the same problem: a terminal environment that has to be identical on five machines. Splitting them into two repositories would double the number of clones, of `git pull`s and of bootstraps per machine, without separating anything that changes for different reasons.

The prefix is `CTRL+Space`, and the keys deliberately repeat WezTerm's mnemonics — `|`, `-`, `hjkl`, `HJKL`, `c`, `[`. The two layers do different things (window and session), but splitting a pane the same way in both is one less thing to remember.

The three prefixes in play do not collide: `CTRL+a` in WezTerm, `CTRL+Space` in tmux, `Space` in LazyVim.

Plugins, pinned by tag where it matters:

| Plugin | What for |
|---|---|
| `tpm` | manager; `prefix + I` installs, `prefix + U` updates |
| `tmux-sensible` | the defaults everyone ends up writing by hand |
| `tmux-yank` | copy to the system clipboard, on all three OSes |
| `tmux-cpu`, `tmux-battery` | the numbers behind the catppuccin widgets |
| `tmux-resurrect`, `tmux-continuum` | sessions survive a reboot, with automatic saving |
| `catppuccin/tmux#v2.3.0` | theme and widgets |

catppuccin is pinned to the tag because it broke compatibility between v1 and v2: a moving `main` would break the status bar one machine at a time, as each one ran `prefix + U`.

### Two orderings that are not negotiable

The status bar is assembled **after** `run tpm`: the `@catppuccin_status_*` modules only come into existence once catppuccin has loaded.

And the `run` lines for `tmux-cpu` and `tmux-battery` come **after** the bar is assembled. Those plugins do not create format variables — they substitute their own placeholders inside the value of `status-right` at the instant they run. Running earlier, they find nothing to substitute and the widgets come out empty. It is also why cpu, ram and battery go into the bar with `set -agF` (the `F` expands the format right there, inlining `#{cpu_percentage}` so the plugin can find it) while the rest go in with `set -ag`.

### Plugin installation does not use `tpm/bin/install_plugins`

TPM's script discovers the plugin directory by running `tmux start-server` **on the default socket**. If there is already a tmux server running with another config, it reads that server's `TMUX_PLUGIN_MANAGER_PATH` and reports "Already installed" for plugins it never cloned — a silent failure, and the bootstrap finishes saying it worked.

`_common.sh` clones directly with `git`, reading the list from `tmux.conf`'s own `@plugin` lines, which remain the single source of truth. TPM keeps working inside the session for `prefix + I` and `prefix + U`.

### The bootstrap does not overwrite `~/.tmux.conf`

`~/.config/tmux/tmux.conf` takes precedence over `~/.tmux.conf`. Creating the link without checking would leave an existing config alive on disk but inert — the worst kind of breakage, because nothing errors out. The bootstrap detects it, warns, and prints the two commands to switch consciously.

---

## Validation

```bash
bash scripts/check.sh
```

**You cannot trust `wezterm`'s exit code.** Verified in practice: with a broken `wezterm.lua`, or with a `machine.lua` full of syntax errors, the command

```bash
wezterm --config-file ./wezterm.lua show-keys
```

finishes with **0** and writes **nothing** to stderr. It silently falls back to the default config. The only observable sign is the `Leader:` line disappearing from the output — and that only works because this config always defines a leader.

For the same reason, checking for the presence of an action like `SplitHorizontal` is useless: WezTerm's default config also has that action. The check has to match `LEADER` **and** the action on the same line.

On the tmux side there are two similar traps. `tmux -f conf start-server` is useless: a server with no session dies immediately, and the next command brings up a new server without the config — `check.sh` uses `new-session -d`. And `show-options -gv status-right` returns the raw format string, which always contains a literal `@catppuccin`; what proves the plugin loaded is the `@thm_*` palette existing.

`check.sh` runs tmux with a disposable `HOME` and socket, so it does not touch the user's session or config.

No CI for now. `check.sh` runs in one second. It is worth setting up a GitHub Actions the day a broken push reaches another machine without anyone noticing.

---

## Plugins

Starting with none, deliberately: predictable startup, fewer dependencies, less risk surface on the work Mac, and guaranteed compatibility across the five scenarios.

The API exists and is available when the time comes:

```lua
local plugin = wezterm.plugin.require('https://github.com/author/plugin-wezterm')
plugin.apply_to_config(config)
```

The first candidate is `smart-splits.nvim`, for the reason in the previous section.

---

## Security

These never enter this repository: SSH keys, GitHub or GitLab tokens, passwords, cookies, corporate credentials, internal hostnames, server addresses, certificates, `.p12` files, environment variables holding secrets, confidential project paths or names.

Anything work-specific goes into `machine.lua`, which `.gitignore` covers.

On a managed machine, check the applicable policy before installing anything.

The scripts in this repository do not install Homebrew, do not use `sudo` on macOS, do not remove quarantine and do not work around MDM — on purpose.

---

## Final configuration per machine

| Machine | Application | Configuration |
|---|---|---|
| Company MacBook | WezTerm macOS | Base + opaque `machine.lua`, no blur |
| Personal MacBook | WezTerm macOS | Base + personal `machine.lua` |
| Personal Windows PC | WezTerm Windows | Base + `default_domain = 'WSL:Ubuntu'` |
| Ubuntu/Debian on WSL | Shell inside the Windows WezTerm | Nothing — no GUI installed |
| Native Linux | WezTerm Linux | Base + Linux `machine.lua` |
