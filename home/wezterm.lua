local wezterm = require "wezterm"
local config = {}

config.enable_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
config.font = wezterm.font "JetBrainsMono Nerd Font"
config.font_size = 11.0
-- Leave room for Fastfetch before Niri applies the final tiled window size.
config.initial_cols = 90
config.initial_rows = 40
config.window_background_opacity = 0.85
config.text_background_opacity = 1.0

-- Colours are rendered by skwd-wall from the wallpaper (home/skwd-theme).
-- Watching the file makes open windows recolour when it is rewritten.
local theme = wezterm.home_dir .. "/.local/state/skwd-theme/wezterm.lua"
wezterm.add_to_config_reload_watch_list(theme)
local ok, colors = pcall(dofile, theme)
if ok then
  config.colors = colors
else
  wezterm.log_warn("skwd theme not loaded: " .. tostring(colors))
end

return config
