local M = {}

local function contains(value, fragment)
  return value:find(fragment, 1, true) ~= nil
end

function M.apply(config, wezterm)
  local target = wezterm.target_triple

  if contains(target, 'apple') then
    config.native_macos_fullscreen_mode = true

    -- Overrides the 'RESIZE' from appearance.lua. 'RESIZE' alone removes the
    -- title bar, and the three macOS buttons go away with it — the close, the
    -- minimize and the fullscreen one all disappear.
    --
    -- INTEGRATED_BUTTONS draws the three inside the tab bar: it keeps the
    -- title-bar-less look and gives the controls back. It is a macOS-only
    -- option, which is why it lives here and not in appearance.
    config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'

    -- No default_prog: WezTerm already uses the shell from /etc/passwd.
    -- Hardcoding '/bin/zsh' breaks for anyone on brew's zsh, fish or nix.
    return
  end

  if contains(target, 'windows') then
    -- ponytail: per-system font_size is visual calibration, not a rule.
    -- Adjust it by what you see on each machine's monitor.
    config.font_size = 12

    -- pwsh is the native default shell. It is IGNORED when machine.lua sets a
    -- WSL default_domain (the two together misbehave, wezterm/wezterm#6147) --
    -- that WSL domain is the intended override for a WSL-first machine. The
    -- launcher below still covers the one-off shells.
    config.default_prog = { 'pwsh.exe', '-NoLogo' }

    config.launch_menu = {
      {
        label = 'PowerShell 7',
        args = { 'pwsh.exe', '-NoLogo' },
      },
      {
        -- Fallback for anyone without PowerShell 7 installed.
        label = 'Windows PowerShell',
        args = { 'powershell.exe', '-NoLogo' },
      },
      {
        label = 'Command Prompt',
        args = { 'cmd.exe' },
      },
    }

    -- One entry per installed WSL distro, detected at startup instead of
    -- hardcoded to a single name -- so every distro shows up (and a machine
    -- with none just gets the shells above). pcall because default_wsl_domains
    -- shells out to `wsl -l`, which errors on a box without the WSL feature.
    local ok_wsl, wsl_domains = pcall(wezterm.default_wsl_domains)
    if ok_wsl and wsl_domains then
      for _, dom in ipairs(wsl_domains) do
        table.insert(config.launch_menu, {
          label = 'WSL ' .. dom.distribution,
          domain = { DomainName = dom.name },
        })
      end
    end

    return
  end

  if contains(target, 'linux') then
    config.font_size = 12

    -- No enable_wayland: default already true since 20220624-141144-bd1b7c5d.
    -- Set false here (or in machine.lua) only if you need to force X11.
    return
  end
end

return M
