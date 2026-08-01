local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- Promotes an invalid option from a warning to an error. Without this a typo
-- (here or in machine.lua) goes unnoticed and the option simply has no
-- effect.
config:set_strict_mode(true)

-- WezTerm only puts the *config directory* on package.path, and that is not
-- this file's directory when the config is reached through WEZTERM_CONFIG_FILE
-- with the repo cloned outside ~/.config/wezterm (require('config.*') then
-- fails and the whole config silently falls back to the default). Add our own
-- directory so the requires below resolve however, and from wherever, this file
-- was loaded. Guarded: if wezterm.config_file is ever unavailable this is a
-- no-op, and the default config-dir behavior stands.
local here = (wezterm.config_file or ''):gsub('[/\\][^/\\]*$', '')
if here ~= '' then
  package.path = here .. '/?.lua;' .. here .. '/?/init.lua;' .. package.path
end

require('config.appearance').apply(config, wezterm)
require('config.keys').apply(config, wezterm)
require('config.platform').apply(config, wezterm)

-- Tweaks exclusive to this machine. machine.lua is not versioned.
-- It can export a table (key merge) or an apply(config, wezterm) function.
local ok, machine = pcall(require, 'machine')

if ok then
  if type(machine) == 'function' then
    machine(config, wezterm)
  elseif type(machine) == 'table' then
    for key, value in pairs(machine) do
      config[key] = value
    end
  end
elseif not tostring(machine):find("module 'machine' not found", 1, true) then
  -- A missing machine.lua is normal; a broken machine.lua has to fail loud,
  -- otherwise the config comes up without the overrides and without any
  -- warning.
  error(machine)
end

return config
