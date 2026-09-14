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
}
