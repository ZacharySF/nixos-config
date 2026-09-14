# Desktop: Niri (Wayland compositor) + the session plumbing around it.
#
# There is no full desktop environment (no GNOME/KDE). Niri is a
# scrollable-tiling compositor; the bar, launcher, notifications, lock screen
# etc. are separate programs configured per-user in ../../home/.
{ pkgs, ... }:
{
  # Installs Niri and registers a `niri` / `niri-session` and a desktop entry.
  programs.niri.enable = true;

  # greetd: minimal login manager. Here it is configured to launch a Niri
  # session for `xelo` directly — effectively autologin into Niri on boot.
  # To get a real login prompt instead, replace `default_session.command`
  # with a greeter like `${pkgs.greetd.tuigreet}/bin/tuigreet --cmd niri-session`.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.niri}/bin/niri-session";
      user = "xelo";
    };
  };

  # Tell Chromium/Electron apps to use native Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # xdg portals: screen sharing, "open file" dialogs, etc. for sandboxed and
  # toolkit apps. gtk backend covers most; niri ships its own portal via the
  # niri module for screencast.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Firefox system-wide (so it works regardless of the user environment state).
  programs.firefox.enable = true;

  # GTK / GNOME app support without the full desktop:
  programs.dconf.enable = true;                 # GTK apps store settings here
  services.gnome.gnome-keyring.enable = true;   # Secret Service API (logins, tokens)
  security.pam.services.greetd.enableGnomeKeyring = true; # unlock keyring at login

  services.dbus.implementation = "dbus"; # keep classic dbus; broker requires reboot to switch
  services.printing.enable = true; # CUPS

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # UI + terminal font with icons (used by ironbar/niri)
    nerd-fonts.symbols-only   # icon glyphs to patch into other fonts
    inconsolata               # foot terminal font
  ];
}
