# ironbar — the status bar spawned by Niri at startup.
#
# config.json / style.css are kept as raw files (they were already hand-tuned
# and ironbar's schema changes often). The battery indicator is a tiny shell
# script that config.json calls every 30s.
{ pkgs, ... }:
{
  home.packages = [ pkgs.ironbar ];

  xdg.configFile."ironbar/config.json".source = ./ironbar/config.json;
  xdg.configFile."ironbar/style.css".source = ./ironbar/style.css;

  # config.json runs this via an absolute path (~/.local/bin/battery-icon.sh).
  home.file.".local/bin/battery-icon.sh" = {
    source = ./ironbar/battery-icon.sh;
    executable = true;
  };
}
