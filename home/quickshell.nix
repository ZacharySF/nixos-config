# nunera/quickshell-bar, vendored at the revision recorded in README.md.
# Keep mako as the notification daemon; Quickshell only owns the desktop bar.
{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [ quickshell material-symbols inotify-tools ];
  xdg.configFile."quickshell/bar".source = ./quickshell;
  xdg.configFile."desktop-style/style.json".text = builtins.toJSON {
    gaps = 6;
    bar = { height = 25; tabletHeight = 44; layout = "islands"; };
    fonts = { text = "JetBrainsMono Nerd Font"; icons = "Material Symbols Rounded"; };
  };

  systemd.user.services.quickshell-bar = {
    Unit = {
      Description = "Quickshell desktop bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      X-Restart-Triggers = [ "${./quickshell}" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.quickshell} -c bar";
      Environment = [
        "BAR_NOTIFICATIONS=0"
        "PATH=${lib.makeBinPath [ pkgs.inotify-tools pkgs.coreutils pkgs.procps pkgs.systemd pkgs.networkmanager pkgs.fuzzel pkgs.foot pkgs.btop ]}:/run/current-system/sw/bin:/etc/profiles/per-user/xelo/bin"
      ];
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
