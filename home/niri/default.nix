# Niri: user-level config file + the helper programs its config launches.
#
# The compositor itself is enabled system-wide in
# modules/system/desktop.nix. This module only:
#   1. installs config.kdl to ~/.config/niri/config.kdl
#   2. installs the small tools referenced by that config
#
# config.kdl is kept as a plain KDL file (not translated to Nix) so it stays
# easy to read/diff against the upstream niri default and easy to hand-edit.
{ pkgs, ... }:
{
  xdg.configFile."niri/config.kdl".source = ./config.kdl;

  # Dark launcher with the same blue border as Niri's active focus ring.
  xdg.configFile."fuzzel/fuzzel.ini".source = ./fuzzel.ini;

  # Without a config, mako's default-timeout is 0 (never expire), so
  # notifications like niri's "Screenshot captured" sit on screen until
  # clicked. Give them a real timeout.
  xdg.configFile."mako/config".source = ./mako.conf;

  home.packages = with pkgs; [
    swaybg          # wallpaper (spawned at startup — see config.kdl)
    mako            # notification daemon
    libnotify       # notify-send — used by Claude Code / Codex hooks for desktop popups
    fuzzel          # application launcher (Mod+D)
    bzmenu          # bluetooth TUI menu (Mod+B)
    swaylock        # screen locker (Super+Alt+L)
    brightnessctl   # XF86MonBrightness keys
    playerctl       # XF86Audio media keys
    xwayland-satellite # run X11-only apps under Niri
  ];

  # Keep both existing wallpaper paths available on every installation.
  home.file."Pictures/wallpaper.jpg".source = ../wallpaper/wallpaper.jpg;
  xdg.configFile."background".source = ../wallpaper/wallpaper.jpg;
}
