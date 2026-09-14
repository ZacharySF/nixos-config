# User-level desktop bits that are not tied to one specific app:
# GTK theme, cursor theme, XDG user directories.
{ pkgs, ... }:
{
  # Consistent dark GTK look for nautilus, pavucontrol, etc.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  # Cursor theme (also exported to the Wayland/XCURSOR env).
  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
  };

  gtk.gtk4.theme = null; # adopt new default (no gtk4 theme override)

  # ~/Documents, ~/Downloads, ~/Pictures/Screenshots (niri saves here), ...
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false; # adopt new default
  };

  # A couple of GUI utilities that belong to "the desktop" rather than dev work.
  home.packages = with pkgs; [
    chromium       # web browser
    nautilus       # file manager
    pavucontrol    # audio mixer
    wl-clipboard
  ];
}
