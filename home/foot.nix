# foot — the Wayland terminal emulator (Mod+Return in Niri).
#
# This was previously ~/.config/foot/foot.ini. home-manager writes that file
# from the attribute set below, so the colours live in version control now.
{ ... }:
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Inconsolata:size=12";
        initial-window-size-chars = "150x38";
        pad = "8x8";
      };
      "colors-dark" = {
        alpha = 0.85;
        background = "0d0b1a";
        foreground = "c4b9e0";

        regular0 = "1a1730";
        regular1 = "ff6e9c";
        regular2 = "7ee8a0";
        regular3 = "f1d576";
        regular4 = "7aa2f7";
        regular5 = "bb9af7";
        regular6 = "7dcfff";
        regular7 = "c0caf5";

        bright0 = "3b3660";
        bright1 = "ff7eb6";
        bright2 = "9ece6a";
        bright3 = "e0af68";
        bright4 = "89b4fa";
        bright5 = "c4a7e7";
        bright6 = "89dceb";
        bright7 = "e0def4";
      };
    };
  };
}
