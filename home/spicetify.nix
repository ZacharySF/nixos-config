# Spotify theming via spicetify-nix (a flake input).
#
# `programs.spicetify` comes from the spicetify-nix home-manager module that
# flake.nix adds as a sharedModule. It builds a patched Spotify, so the
# `spotify` command / desktop entry are provided here too.
{ inputs, pkgs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      beautifulLyrics
    ];
  };

  # Avoid the locked-keyring prompt when opening Spotify from the launcher.
  # Basic storage does not use keyring encryption for Spotify's local credentials.
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    icon = "spotify-client";
    exec = "spotify --password-store=basic %U";
    terminal = false;
    mimeType = [ "x-scheme-handler/spotify" ];
    categories = [ "Audio" "Music" "Player" "AudioVideo" ];
    settings = {
      TryExec = "spotify";
      StartupWMClass = "spotify";
    };
  };
}
