# GUI editors / notes apps.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Zed — fast editor. The `-fhs` variant runs inside an FHS sandbox so
    # downloaded language servers / extensions work without patching.
    # This REPLACES the manual ~/.local/zed.app install (you can delete that
    # directory and the ~/.local/bin/zed symlink after switching).
    zed-editor-fhs

    vscode
    obsidian
  ];

  # Zed settings. NOTE: home-manager installs this as a read-only symlink, so
  # editing settings from Zed's UI will fail — edit this file in the repo
  # instead and `rebuild`.
  xdg.configFile."zed/settings.json".source = ./zed/settings.json;
}
