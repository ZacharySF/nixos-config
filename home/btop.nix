# btop — resource monitor. (Also installed system-wide for TTY rescue use;
# this just manages the user config.)
{ ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "skwd-managed"; # rendered by skwd-wall (home/skwd-theme)
      theme_background = true;
      truecolor = true;
      rounded_corners = true;
      vim_keys = false;
      update_ms = 1500;
    };
  };
}
