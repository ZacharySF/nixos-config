# Desktop: Niri (Wayland compositor) + the session plumbing around it.
#
# There is no full desktop environment (no GNOME/KDE). Niri is a
# scrollable-tiling compositor; the bar, launcher, notifications, lock screen
# etc. are separate programs configured per-user in ../../home/.
{ pkgs, ... }:
{
  # Installs Niri and registers a `niri` / `niri-session` and a desktop entry.
  programs.niri.enable = true;

  # greetd: minimal login manager. tuigreet prompts for a username/password
  # and then launches a Niri session on successful auth.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --cmd niri-session";
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
  # Pin the portal backend explicitly. Without this, xdg-desktop-portal-gnome
  # (pulled in transitively, not asked for anywhere in this config — there is
  # no GNOME session here) gets dbus-activated alongside the gtk portal we
  # actually want, running two portal implementations for no reason.
  xdg.portal.config.common.default = [ "gtk" ];

  # speech-dispatcher gets dbus-activated by something in the GTK/a11y stack
  # even though nothing here uses a screen reader. Mask it; if you ever wire
  # up accessibility/TTS, flip this back.
  systemd.user.services.speech-dispatcher.enable = false;

  # Firefox system-wide (so it works regardless of the user environment state).
  programs.firefox.enable = true;
  programs.chromium.enable = true;

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
