# skwd-wall — wallpaper selector/engine (github:liixini/skwd-wall, `nix` branch).
# The upstream module installs the suite (skwd-wall-v2, lens model) and the
# `skwd-walld` user daemon. Launch the picker with Mod+Y (home/niri/config.kdl).
# Palette integrations (Ironbar, Niri, ...) live in home/skwd-theme.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.skwd-wall.nixosModules.default ];

  services.skwd-deck.enable = true;

  # The daemon runs every integration reload hook as `setsid -f sh -c ...`,
  # falling back to plain `sh -c ...`. The unit's default PATH has neither
  # (only coreutils/findutils/grep/sed/systemd), so every hook failed with
  # "detached hook spawn failed: No such file or directory".
  systemd.user.services.skwd-walld.path = [
    pkgs.bash # sh
    pkgs.util-linux # setsid
  ];
}
