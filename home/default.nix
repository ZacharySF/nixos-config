# home-manager entry point for user `xelo`.
#
# Imported by flake.nix as `home-manager.users.xelo`. Each file below owns one
# area of the user environment.
{ ... }:
{
  imports = [
    ./shell.nix      # bash, prompt, CLI tools, direnv
    ./git.nix        # git identity + gh
    ./niri           # Niri config file + session helper tools
    ./desktop.nix    # GTK theme, cursor, xdg user dirs
    ./foot.nix       # terminal emulator
    ./ironbar.nix    # status bar
    ./btop.nix       # system monitor config
    ./editors.nix    # zed / vscode / obsidian
    ./dev.nix        # quant + computer-architecture toolchain
    ./spicetify.nix  # Spotify theming
  ];

  home.username = "xelo";
  home.homeDirectory = "/home/xelo";

  # Same meaning as system.stateVersion but for home-manager. Leave pinned.
  home.stateVersion = "25.11";

  # Let home-manager manage itself.
  programs.home-manager.enable = true;
}
