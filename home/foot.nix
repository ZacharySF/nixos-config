# foot — the Wayland terminal emulator.
#
# home-manager writes ~/.config/foot/foot.ini from the attribute set below.
# Colours come from skwd-wall (home/skwd-theme) via `include`; foot reads them
# when a new window opens.
{ ... }:
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Inconsolata:size=12";
        initial-window-size-chars = "150x38";
        pad = "8x8";
        include = "/home/xelo/.local/state/skwd-theme/foot.ini";
      };
      "colors-dark".alpha = 0.85;
    };
  };
}
