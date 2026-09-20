# User-level desktop bits that are not tied to one specific app:
# GTK theme, cursor theme, XDG user directories.
{ pkgs, ... }:
{
  # Firefox is installed system-wide (modules/system/desktop.nix); this just
  # manages profile prefs. Site isolation (Fission) spawns a fresh content
  # process pretty liberally by default — cap the pool so it reuses processes
  # across same-site tabs instead of growing unbounded. Cross-origin isolation
  # is unaffected.
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "dom.ipc.processCount" = 4;
        "browser.tabs.unloadOnLowMemory" = true;
      };
    };
  };

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

  # Nautilus and other GTK4/libadwaita apps ignore gtk.theme above and
  # instead follow this toggle for their light/dark variant.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

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
    wezterm       # terminal emulator
    wl-clipboard
    libreoffice    # opens .docx/.doc/.odt/.xlsx/.pptx and more
  ];
}
