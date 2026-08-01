local M = {}

-- Catppuccin Mocha in dark, Latte in light.
local function scheme_for(appearance)
  if appearance:find('Dark') then
    return 'Catppuccin Mocha'
  end

  return 'Catppuccin Latte'
end

function M.apply(config, wezterm)
  -- wezterm.gui does not exist in the mux server context, nor in some CLI
  -- subcommands. Without the guard, `wezterm show-keys` breaks.
  local appearance = wezterm.gui and wezterm.gui.get_appearance() or 'Dark'

  config.color_scheme = scheme_for(appearance)

  config.font = wezterm.font_with_fallback({
    {
      family = 'JetBrainsMono Nerd Font Mono',
      weight = 'Regular',
    },
    'JetBrains Mono',
    'Symbols Nerd Font Mono',
  })

  -- macOS baseline. platform.lua adjusts it for Windows and Linux.
  config.font_size = 13
  config.line_height = 1.1

  config.harfbuzz_features = {
    'calt=1',
    'clig=1',
    'liga=1',
  }

  config.window_background_opacity = 0.96
  config.macos_window_background_blur = 20
  config.window_decorations = 'RESIZE'

  config.window_padding = {
    left = 10,
    right = 10,
    top = 8,
    bottom = 8,
  }

  config.use_fancy_tab_bar = false
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = false

  config.initial_cols = 130
  config.initial_rows = 34
  config.scrollback_lines = 10000

  -- Opens already in fullscreen.
  --
  -- Only `gui-startup` can do this: there is no config option for the
  -- initial window state, you have to create the window and call the method
  -- on it. The event fires once, when the GUI comes up.
  --
  -- To turn it off on a specific machine, put this in machine.lua, BEFORE
  -- anything else:
  --     WEZTERM_START_FULLSCREEN = false
  -- It is read in here at the moment the window opens, so the load order
  -- sorts itself out.
  --
  -- Swapping it for `:maximize()` gives a big window without going fullscreen
  -- — on macOS that avoids the new Space and the native fullscreen animation.
  wezterm.on('gui-startup', function(cmd)
    local _, _, window = wezterm.mux.spawn_window(cmd or {})

    if WEZTERM_START_FULLSCREEN ~= false then
      window:gui_window():toggle_fullscreen()
    end
  end)
end

return M
