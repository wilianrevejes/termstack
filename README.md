# termstack

A terminal environment shared across a work MacBook, a personal MacBook, a Windows PC (with WSL) and native Linux.

**Main stack:** [WezTerm](https://wezterm.org) + [Zellij](https://zellij.dev) + [LazyVim](https://lazyvim.github.io).
**Fallback:** [tmux](https://github.com/tmux/tmux), installed and configured, but not the default.

One versioned base that is identical on every machine, plus a local `machine.lua` that Git ignores for the per-machine differences.

The reasoning behind the choices lives in [`DESIGN.md`](DESIGN.md).

```text
wezterm.lua              WezTerm: entry point
config/                  appearance, keys, platform
zellij/config.kdl        Zellij: starts locked, C-Space prefix
zellij/layouts/dev.kdl   nvim + terminal layout (zj -n dev)
nvim/                    vendored LazyVim (+ lazy-lock.json)
tmux/tmux.conf           tmux: C-Space prefix, catppuccin, widgets
zsh/                     oh-my-zsh + powerlevel10k, catppuccin
i18n/                    message catalogs, one file per language
mise/config.toml         CLI versions, under version control
machine.example.lua      template for the per-machine tweak
scripts/setup.sh         entry point: preflight + bootstrap + check
scripts/update.sh        updates everything, with snapshot and rollback
```

## Install

One command:

```bash
git clone git@github.com:YOUR-USER/termstack.git "$HOME/.config/wezterm"
cd "$HOME/.config/wezterm"

bash scripts/setup.sh
```

```powershell
git clone "git@github.com:YOUR-USER/termstack.git" "$HOME\.config\wezterm"
Set-Location "$HOME\.config\wezterm"
.\scripts\setup-windows.ps1     # native Windows stack: WezTerm + Zellij + Neovim + pwsh
```

If Windows PowerShell 5.1 refuses with "running scripts is disabled on this system", start it from a terminal instead: `powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1`.

**Installation always goes through `setup.sh`** — the bootstrap scripts are called by it, not directly. It detects the system and walks you through five steps:

| Step | What it does |
|---|---|
| 1. diagnose | Looks for what already exists and would get in the way. **Changes nothing.** If it finds a conflict, it asks whether you want it resolved |
| 2. install | Tools via mise, WezTerm and the font, config links, plugins |
| 3. terminal | Hands off to a WezTerm window, so the remaining steps run with the Nerd Font active |
| 4. prompt | If `POWERLEVEL9K_MODE` does not match the installed font, offers to run `p10k configure` |
| 5. verify | Confirms all four layers really load, then lists the next steps |

It is idempotent and **never uninstalls or overwrites anything**. Whatever already exists and conflicts is left alone, with a warning.

```bash
bash scripts/setup.sh --clean   # resolve conflicts up front, with a backup first
bash scripts/setup.sh --yes     # never ask anything (automation)
```

`--yes` means "do not ask me", not "yes to everything": without `--clean` alongside it, nothing gets moved.

The steps also run on their own if you need them to:

```bash
bash scripts/preflight.sh           # diagnose only
bash scripts/check.sh               # verify only
```

### About the prompt step

The powerlevel10k wizard **does not detect fonts** — it records the mode based on *your answers* to its glyph questions. Run it in a terminal without the Nerd Font active, you answer "I don't see it", and it records the fallback. Then the icons turn into ugly stand-ins (`∅` for the lock, `≡` for jobs).

That is why step 4 only *offers* the wizard, with a warning: run it inside a WezTerm that already has the font. It rewrites the **repository's** `zsh/p10k.zsh` (not `~/.p10k.zsh`), so one answer covers every machine once you commit it.

Windows has **two independent setups**. `setup-windows.ps1` installs the **native** stack via winget — WezTerm, the Nerd Font, **Zellij** (native since v0.44), **Neovim/LazyVim**, and the CLI tools (ripgrep, fd, lazygit, fzf, zoxide, bat, node, plus `zig` for treesitter) — wires their configs, and runs **pwsh** as the shell. No WSL required. What the native flow does **not** include: **zsh/oh-my-zsh/powerlevel10k** and **tmux**, which are Unix-only.

For that zsh/tmux layer, run the **Linux setup** inside a WSL distro (or any Linux), on the distro filesystem (not `/mnt/c`):

```bash
git clone <repo> ~/.config/wezterm
cd ~/.config/wezterm && bash scripts/setup.sh
```

It detects WSL and skips WezTerm, since rendering there is done by the Windows WezTerm. WezTerm's launcher (`Ctrl+a` then `Space`) lists both pwsh and every installed WSL distro, so you can keep both worlds on one machine.

After bootstrap, reopen the shell (`exec $SHELL`) so `mise` lands on your `PATH`.

### Where each piece comes from

The CLI tools come from [`mise`](https://mise.jdx.dev), which downloads prebuilt binaries into `~/.local` **without sudo**. That is what lets a managed work Mac — where Homebrew needs sudo for the default prefix — use exactly the same path as the other four machines:

| Tool | Source |
|---|---|
| neovim, zellij, tmux, lazygit, ripgrep, fd, fzf, zoxide, bat | `mise`, always `@latest` |
| node | `mise`, `lts` channel |
| oh-my-zsh, powerlevel10k, zsh and tmux plugins | `git clone`, updated by `update.sh` |
| WezTerm | Homebrew / winget / distro repo |
| JetBrainsMono Nerd Font | Homebrew / winget, or a direct release download |

The font is never left out: where there is no Homebrew and no winget — Linux, and the managed Mac — the bootstrap downloads `JetBrainsMono.tar.xz` from the official release (5 MB, same content as the 123 MB zip) and extracts it into `~/.local/share/fonts` or `~/Library/Fonts`. No sudo.

**Stable WezTerm is the February 2024 build** — the same one in the cask, in winget, in scoop and in apt. "Up-to-date WezTerm" means nightly, on every platform; that is why the `Brewfile` uses `wezterm@nightly`.

### One manual step that cannot be automated

Open Zellij and press `Ctrl+Space`. The mode indicator in the status bar has to switch to **TMUX**. If it does not, your terminal cannot tell that combination apart — change the bind in `zellij/config.kdl` (Zellij's own default is `Ctrl+b`).

### If you would rather keep the repository somewhere else

```bash
ln -s ~/dev/termstack ~/.config/wezterm                   # symlink
export WEZTERM_CONFIG_FILE=~/dev/termstack/wezterm.lua    # environment variable
```

### If you already have a tmux or Neovim config

The bootstrap does **not** overwrite it. It detects the conflict, warns, and skips the link. To switch deliberately:

```bash
mv ~/.tmux.conf ~/.tmux.conf.bak
ln -s ~/.config/wezterm/tmux ~/.config/tmux
```

For tmux the warning matters: `~/.config/tmux/tmux.conf` takes precedence over `~/.tmux.conf`, so creating the link would leave your old config alive on disk but inert — the worst kind of breakage, because nothing errors out.

## Cheatsheet

`setup.sh` prints a summary of the keys and commands of all four layers at the end. It also opens with every new WezTerm shell. To see it again at any moment:

```bash
stack                                   # alias, available in the repository's shell
bash ~/.config/wezterm/scripts/cheatsheet.sh
```

Or by key: `Ctrl+a ?` in WezTerm, `Ctrl+Space ?` inside Zellij. Both close on any key — WezTerm opens it in a tab and Zellij in a floating pane, because the sheet is taller than a split.

## Language

Every string the scripts print lives in `i18n/`, one file per language. English
ships as the reference; `pt-BR` ships as a second one.

```bash
TERMSTACK_LANG=pt-BR bash scripts/setup.sh
```

Without that variable the language is picked from `$LANG`, falling back to
English. To add one, copy `i18n/en.sh`, translate the values, and name it after
the tag you want to select with.

You do not have to translate everything: `en.sh` is sourced first and your file
on top, so a key you leave out keeps its English text instead of printing an
empty line. Three tests guard the catalogs — that every key used by a script
exists in `en.sh`, that no translation defines a key English does not have, and
that the cheatsheet stays inside 78 columns **in every language** (Portuguese
words are longer, and that is where it overflows first).

## Shell

The repository does **not** change or install your shell. It only appends a marked block to your `~/.zshrc` (or `~/.bashrc`) with the minimum the stack needs:

```sh
# >>> termstack >>>
eval "$(mise activate zsh)"
export EDITOR=nvim
export VISUAL=nvim
# <<< termstack <<<
```

Activating mise is what puts the tools on `PATH`. `EDITOR` is not a preference: Zellij resolves the scrollback editor **once, at startup**, and falls back to the literal `vi` if the variable is not already set.

Use zsh on macOS and bash on Linux/WSL — each platform's default. Unifying them is not worth it:

- **Nothing in the stack depends on the shell.** Zellij uses `$SHELL` for `default_shell`, WezTerm reads the shell from `passwd`.
- **fish and nushell are not in `/etc/shells` on macOS**, and adding them requires `sudo` — blocked on exactly the managed Mac this has to work on.
- **fish is not POSIX**, and the friction shows up right where this repository lives: sourcing snippets, install one-liners, `sh -c` fired by a Neovim plugin.

`mise` activates in bash, zsh, fish, nushell, elvish, xonsh and PowerShell, but only bash, zsh and fish have full support — nushell and PowerShell have no shell aliases.

## Update

One command, on the machine you want to update:

```bash
bash ~/.config/wezterm/scripts/update.sh
```

In order: takes a **snapshot** of the current state, runs `git pull`, redoes the links, updates the tools (`mise upgrade`, `brew`, WezTerm nightly), the tmux plugins and the Neovim ones, and runs the verification at the end.

**If the verification fails, it rolls back to the snapshot on its own** and runs the verification again, so you know whether the rollback fixed it. The machine does not stay broken because a bad commit arrived through the pull.

The snapshot stores the repository SHA, `machine.lua`, `lazy-lock.json`, `lazyvim.json`, the tool versions, where each link pointed, and a copy of your `~/.zshrc`, `~/.zshenv` and `~/.zshrc.local`.

It lives **outside the repository**, in `~/.local/state/termstack/backup/<timestamp>/`, and only the 5 most recent are kept. Outside on purpose: those files carry SDK paths and work-specific variables, and keeping them inside a directory headed for GitHub would depend on a single `.gitignore` line to not leak.

To roll back by hand:

```bash
bash scripts/update.sh --rollback              # latest snapshot
bash scripts/update.sh --rollback ~/.local/state/termstack/backup/20260731-140000
```

Tool versions are not reverted automatically — a downgrade costs a download and is rarely the cause. The previous versions are recorded in the snapshot.

Offline, the script skips everything that needs the network and still redoes the links and the local config.

## Keys

Four layers that do not collide. The rule that organizes everything: **Zellij starts locked** (`default_mode "locked"`), and in locked mode it captures no key at all beyond the one that enters a mode.

**`Ctrl+h/j/k/l` belongs to Neovim. Always, across all four layers.** That is what makes a navigation plugin unnecessary — and it is just as well, because every one of them available today has broken detection (see the design notes).

| Layer | Prefix | For |
|---|---|---|
| WezTerm | `Ctrl+a` | terminal windows, tabs and panes |
| Zellij | `Ctrl+Space` | multiplexer sessions, tabs and panes |
| tmux (fallback) | `Ctrl+Space` | same — they never run together |
| LazyVim | `Space` | the editor |

Zellij and tmux share a prefix on purpose: they never run at the same time, and the sub-keys are identical. If you forget which one you are in, your fingers still land right. To find out, look at the bar: tmux shows cpu/ram/battery, Zellij shows the mode indicator.

**Identical sub-keys across all three multiplexers** (after the prefix):

| Key | Action |
|---|---|
| `\|` | split side by side |
| `-` | split stacked |
| `x` | close the pane |
| `z` | zoom the pane |
| `h` `j` `k` `l` | move between panes |
| `c` | new tab |
| `n` / `p` | next / previous tab |
| `[` | scroll / copy mode |
| the prefix, twice | sends the literal prefix through |

WezTerm only: `LEADER H J K L` resizes, `LEADER 1..9` jumps to tab N, `LEADER space` opens the launcher, `LEADER ?` opens the cheatsheet.
Zellij only: `Ctrl+Space f` toggles floating panes, `Ctrl+Space w` opens the session manager, `Ctrl+Space space` cycles the swap layouts, `Ctrl+Space d` detaches, `Ctrl+Space ?` opens the cheatsheet, `Esc` always returns to locked.
tmux only: `prefix r` reloads, `prefix I` installs plugins, `prefix U` updates them, `prefix ?` lists every binding.

**Three known collisions, all with an escape hatch:**

1. `Ctrl+a` shadows readline's start-of-line. Escape: `Ctrl+a Ctrl+a`.
2. `Ctrl+Space` shadows blink.cmp (LazyVim's manual completion). Escape: press the prefix twice, or remap the trigger to `<C-n>`.
3. `Ctrl+g` shadows Vim's `:file` — it is Zellij's emergency entrance if `Ctrl+Space` never arrives. `:f` does the same thing.

### Open a project

Neovim never changes its working directory: a path argument opens a buffer and leaves the cwd wherever the shell was. LazyVim's root detection recovers from that for a **file** argument, but `persistence.nvim` keys the session file off `getcwd()` alone, with no fallback — so the session silently becomes a different one. **`cd` first and all three (grep, lazygit, sessions) agree.**

```bash
cd ~/proj && v                      # v = nvim; z proj jumps there by frecency
zj -s proj -n dev                   # new Zellij session: nvim + terminal, both rooted here
zj a -f proj                        # back to it later (-f re-runs the layout's commands)
```

Already inside a multiplexer there is nothing special to type: `Ctrl+Space c` (Zellij) and `prefix c` (tmux) open a tab that **inherits the focused pane's cwd**, and so do the `|` and `-` panes — so `cd` once, then `v` in whichever pane you want the editor. For another directory without leaving this one:

```bash
zj action new-tab -c ~/other        # Zellij: -c is --cwd here, and ONLY on new-tab
                                    # then type v in the new tab
tmux neww -c ~/other nvim           # tmux: same idea, and it takes the command too
```

Two traps worth knowing. On `zellij run` and `zellij action new-pane`, `-c` means `--close-on-exit`, not `--cwd` (the long form is the only one that sets a directory there). And `-l dev` adds the layout as a tab, but swap layouts are session-scoped: only a session started with `-n dev` gets the `vertical / horizontal / stacked` cycle from `zellij/layouts/dev.swap.kdl`.

## Verify

```bash
bash scripts/check.sh
```

Checks all four layers: the WezTerm config loading with the leader bindings, tmux coming up with `C-Space` and catppuccin with its widgets substituted, Zellij's `config.kdl` valid and pointing at the repository, the Neovim links, and the files that have to be in Git.

**Do not trust `wezterm`'s exit code on its own.** `wezterm show-keys` exits 0 even with a broken config: it silently falls back to the default config and writes nothing to stderr. The reliable signal is indirect — the `Leader:` line disappearing from the output.

`check.sh` runs tmux under a throwaway `HOME` and socket, so it never touches your session or your config.

By default only what needs action shows up; whatever passed becomes a per-group count. To see it check by check — useful when the question is "was this even verified?" — use `TERMSTACK_VERBOSE=1`, which works for `preflight.sh` too:

```bash
TERMSTACK_VERBOSE=1 bash scripts/check.sh
```

## Managed work Mac

The scripts do not use `sudo` on macOS, do not install Homebrew, do not strip quarantine and do not work around MDM. Without Homebrew, `mise` installs the CLI tools into `~/.local` all the same and the bootstrap prints manual instructions for WezTerm and the font.

On a managed machine four things can block you, and none of them has a workaround in the script:

1. **Gatekeeper policy** can refuse WezTerm without even showing a dialog.
2. **A security agent** (CrowdStrike, SentinelOne, Jamf Protect) can block a binary downloaded into `~/.local/bin` — exactly what mise does.
3. **A TLS-inspecting proxy** breaks the downloads with certificate errors. It needs `HTTPS_PROXY` and the company CA in the trust store.
4. **Homebrew** will not install into the default prefix without sudo.

`check.sh` detects MDM and says so, so that a failure becomes a diagnosis instead of a mystery. If WezTerm is blocked, the rest of the stack still works inside whatever terminal the company does allow.

On a managed machine, check the applicable policy before installing anything.

## If you are not the owner of this repository

This is one person's terminal configuration, published because it may be useful as a reference — it is not a general-purpose installer.

**Before running `setup.sh` on your machine, know what it does:**

- Installs WezTerm, Zellij, Neovim, tmux, lazygit, ripgrep, fd, fzf, zoxide, bat and node, plus oh-my-zsh and powerlevel10k.
- Creates links from `~/.config/{wezterm,zellij,nvim,tmux}` and `~/.config/mise/config.toml` to the clone.
- Appends a block to your `~/.zshrc`.
- With `--clean`, **moves** conflicting existing configuration to `.bak` (with a backup first, in `~/.local/state/termstack/backup`).

It was written to never overwrite anything: whatever already exists and conflicts is left alone, with a warning. But the real testing happened on the author's machines, not yours.

**And the part that matters most: `update.sh` runs `git pull` and then executes what it just downloaded** — scripts, configs and plugins. Pointing it at someone else's repository hands them, and anyone who ever compromises their account, code execution on your machine at every update. If you are going to use this for real, **fork it** and update from your fork, reviewing the diff before pulling changes in.

Run the diagnosis first, which changes nothing:

```bash
bash scripts/preflight.sh
```

And read `zsh/zshrc`, `zellij/config.kdl` and `config/keys.lua` first — the key choices are opinionated.

## License and attribution

MIT for everything original here — see [`LICENSE`](LICENSE). Attribution for
third-party material is in [`NOTICE`](NOTICE).

Two sets of files come from other projects and keep their own licenses; the
MIT above does not relicense them:

| What | License | Where |
|---|---|---|
| Eight files under `nvim/`, byte-identical copies of the [LazyVim starter](https://github.com/LazyVim/starter) | Apache 2.0 | full text and file list in [`nvim/LICENSE`](nvim/LICENSE) |
| `zsh/p10k.zsh`, generated by the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) wizard | MIT | notice in [`LICENSE`](LICENSE) |

Everything else the stack uses — oh-my-zsh, the zsh and tmux plugins, the
Neovim plugins, the Nerd Font, and the tools themselves — is **not**
distributed here. The scripts fetch it from upstream at install time and each
keeps its own license. What is versioned in this repository is the
configuration that drives them, plus the pinned versions.

### Licenses of what gets installed

Everything this stack installs is under a permissive or free license — MIT,
Apache 2.0, BSD-3-Clause, ISC, Unlicense, SIL OFL — with no restriction on
commercial or workplace use. There is no BSL, SSPL or "source available"
license anywhere in the dependency set.

Two of them are worth knowing about before you change how this repository
works:

- **`bufferline.nvim` and `nvim-lint` are GPL-3.0.** They arrive through
  LazyVim's defaults. That is fine here because this repository does not
  distribute them: `nvim/lazy-lock.json` records a name and a commit SHA,
  which is a reference and not code, and GPL obligations attach to
  distribution rather than to use.
- **The JetBrains Mono Nerd Font is SIL OFL 1.1**, which forbids selling the
  font on its own and requires a modified font to be renamed.

Both stay harmless for the same reason: this repository **installs**
dependencies, it does not **package** them. If you fork it and commit the
plugin directories or the `.ttf` files into the tree, you start
redistributing, and those two licenses then apply to your fork — the MIT
above does not cover them.

## What never enters this repository

SSH keys, tokens, passwords, certificates, `.p12` files, cookies, credentials, internal hostnames or addresses, confidential project names, environment variables holding secrets.

Anything work-specific goes in `machine.lua`, which Git ignores.
