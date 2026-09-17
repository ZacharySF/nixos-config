local wezterm = require "wezterm"
local config = {}

config.enable_tab_bar = false
config.font = wezterm.font "JetBrainsMono Nerd Font"
config.font_size = 11.0
-- Leave room for Fastfetch before Niri applies the final tiled window size.
config.initial_cols = 90
config.initial_rows = 40
config.window_background_opacity = 0.85
config.text_background_opacity = 1.0
config.colors = {
  background = "#171b34",
  foreground = "#c5ccef",
  cursor_bg = "#79c7e8",
  cursor_fg = "#171b34",
  ansi = {
    "#202744", "#9b83c4", "#719fc4", "#8f8fd0",
    "#7185e8", "#ad82c8", "#63bfc1", "#c5ccef",
  },
  brights = {
    "#536083", "#c0a5e8", "#8bc0e8", "#aaa9ed",
    "#91a2ff", "#c29be0", "#82d9d5", "#e0e5ff",
  },
}

return config
