local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action

  -- tmux-style leader. The same on all three systems: same muscle memory on
  -- the work Mac, on the personal Mac, on Windows and on Linux.
  config.leader = {
    key = 'a',
    mods = 'CTRL',
    timeout_milliseconds = 1000,
  }

  local keys = {
    -- LEADER CTRL+a sends a literal CTRL+a. Without this, tmux/emacs/readline
    -- running inside the terminal are left without their own prefix.
    {
      key = 'a',
      mods = 'LEADER|CTRL',
      action = act.SendKey({ key = 'a', mods = 'CTRL' }),
    },

    -- Panes. `|` puts them side by side, `-` stacks them.
    {
      key = '|',
      mods = 'LEADER|SHIFT',
      action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
    },
    {
      key = '-',
      mods = 'LEADER',
      action = act.SplitVertical({ domain = 'CurrentPaneDomain' }),
    },
    {
      key = 'x',
      mods = 'LEADER',
      action = act.CloseCurrentPane({ confirm = true }),
    },
    {
      key = 'z',
      mods = 'LEADER',
      action = act.TogglePaneZoomState,
    },

    -- Navigation between panes.
    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection('Left') },
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection('Down') },
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection('Up') },
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection('Right') },

    -- Resizing (same keys with SHIFT).
    { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize({ 'Left', 3 }) },
    { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize({ 'Down', 3 }) },
    { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize({ 'Up', 3 }) },
    { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize({ 'Right', 3 }) },

    -- Tabs.
    { key = 'c', mods = 'LEADER', action = act.SpawnTab('CurrentPaneDomain') },
    { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
    { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },

    -- Copy mode and launcher (the launcher is what gives access to the
    -- launch_menu defined in platform.lua on Windows).
    { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
    { key = ' ', mods = 'LEADER', action = act.ShowLauncher },

    -- The four-layer cheatsheet, in a pane that closes on any key.
    --
    -- The `read -rsn1` at the end is mandatory: without it the pane prints
    -- and dies at the same instant, and nothing is left to read.
    --
    -- config_dir and not a fixed path: the repository may be cloned into
    -- ~/.config/wezterm or symlinked from anywhere.
    --
    -- For the EXHAUSTIVE list of what is bound right now, WezTerm already
    -- has CTRL+SHIFT+P (command palette) — this one is the curated version.
    {
      key = '?',
      mods = 'LEADER|SHIFT',
      action = act.SplitPane({
        direction = 'Down',
        size = { Percent = 70 },
        command = {
          args = {
            'bash',
            '-c',
            'bash ' .. wezterm.shell_quote_arg(wezterm.config_dir .. '/scripts/cheatsheet.sh')
              .. '; read -rsn1',
          },
        },
      }),
    },
  }

  -- LEADER 1..9 goes straight to tab N.
  for i = 1, 9 do
    table.insert(keys, {
      key = tostring(i),
      mods = 'LEADER',
      action = act.ActivateTab(i - 1),
    })
  end

  config.keys = keys
end

return M
