# skwd-theme — app colours follow the palette skwd-wall derives from each wallpaper.
#
# Uses skwd-wall's own "integrations" (config.json). For every app:
#   templates/<app>-theme.*  colour-only template, copied into
#                            ~/.config/skwd-wall-v2/matugen/templates/ if missing
#                            (so edits made there survive rebuilds)
#   output                   rendered by skwd into ~/.local/state/skwd-theme/
#                            (btop: its themes dir); the app's Nix-managed config
#                            includes it. A fallback copy is seeded if missing.
#   hook                     reload command, installed at a stable path under
#                            ~/.config/skwd-theme/hooks/ so config.json never has
#                            to change when store paths do.
# Integrations are only ever ADDED to config.json (matched by name); existing
# entries, wallpaper profiles and anything else the GUI wrote are left alone.
{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  stateRel = ".local/state/skwd-theme"; # also hard-coded in the raw app configs
  templatesDir = "${config.xdg.configHome}/skwd-wall-v2/matugen/templates";
  configJson = "${config.xdg.configHome}/skwd-wall-v2/config.json";

  # Used only for seeded fallback files (first login, before skwd has run).
  fallbackPalette = {
    background = "#1a1b26";
    on_background = "#c0caf5";
    surface = "#171b34";
    on_surface = "#c5ccef";
    surface_variant = "#1d1f30";
    on_surface_variant = "#a6adc8";
    surface_container = "#1d1f30";
    surface_container_high = "#313244";
    primary = "#8caff0";
    on_primary = "#181825";
    primary_container = "#303c60";
    on_primary_container = "#e0e5ff";
    secondary = "#91a2ff";
    secondary_container = "#2a3150";
    tertiary = "#c4a7e7";
    tertiary_container = "#3b3660";
    outline = "#585b70";
    outline_variant = "#383b50";
    error = "#f7768e";
    ansi_red = "#ff6e9c";
    ansi_green = "#7ee8a0";
    ansi_yellow = "#f1d576";
    ansi_blue = "#7aa2f7";
    ansi_magenta = "#bb9af7";
    ansi_cyan = "#7dcfff";
    ansi_red_bright = "#ff7eb6";
    ansi_green_bright = "#9ece6a";
    ansi_yellow_bright = "#e0af68";
    ansi_blue_bright = "#89b4fa";
    ansi_magenta_bright = "#c4a7e7";
    ansi_cyan_bright = "#89dceb";
  };

  renderFallback =
    name: text:
    let
      roles = builtins.attrNames fallbackPalette;
      from = lib.concatMap (r: [
        "{{colors.${r}.default.hex}}"
        "{{colors.${r}.default.hex_stripped}}"
      ]) roles;
      to = lib.concatMap (r: [
        fallbackPalette.${r}
        (lib.removePrefix "#" fallbackPalette.${r})
      ]) roles;
      out = builtins.replaceStrings from to text;
    in
    assert lib.assertMsg (!lib.hasInfix "{{" out)
      "skwd-theme: fallback for ${name} has a placeholder missing from fallbackPalette";
    pkgs.writeText "skwd-theme-fallback-${name}" out;

  hook =
    name: runtimeInputs: text:
    pkgs.writeShellApplication {
      name = "skwd-theme-${name}";
      inherit runtimeInputs text;
    };

  hooks = {
    # Ironbar hot-reloads a sheet registered with `style load-css`, but every
    # call adds another CSS provider plus an inotify instance (a per-user limit
    # shared by all apps). Register it once per Ironbar process; its own
    # watcher picks up every later render. The @import in style.css covers
    # startup colours.
    ironbar = hook "ironbar" [ pkgs.procps pkgs.coreutils pkgs.ironbar ] ''
      uid=$(id -u)
      pid=$(pgrep -n -u "$uid" -x 'ironbar|\.ironbar-wrappe') || exit 0
      stat=$(cat "/proc/$pid/stat") || exit 0
      instance="$pid $(printf '%s\n' "''${stat##*) }" | cut -d' ' -f20)"
      marker="''${XDG_RUNTIME_DIR:-/run/user/$uid}/skwd-theme-ironbar"
      [ "$(cat "$marker" 2>/dev/null)" = "$instance" ] && exit 0
      ironbar style load-css "${home}/${stateRel}/ironbar.css" >/dev/null
      printf '%s\n' "$instance" > "$marker"
    '';
    mako = hook "mako" [ pkgs.mako ] "makoctl reload || true";
    btop = hook "btop" [ pkgs.procps pkgs.coreutils ] ''pkill -USR2 -u "$(id -u)" -x btop || true'';
    # GTK4/libadwaita apps follow this key; GTK3 apps keep gtk.theme.
    gtk-mode = hook "gtk-mode" [ pkgs.jq pkgs.glib ] ''
      scheme="''${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall-v2/scheme.json"
      mode=$(jq -r '.mode // empty' "$scheme" 2>/dev/null || true)
      case "$mode" in
        dark) want=prefer-dark ;;
        light) want=prefer-light ;;
        *) exit 0 ;;
      esac
      export GSETTINGS_SCHEMA_DIR="${pkgs.glib.getSchemaPath pkgs.gsettings-desktop-schemas}"
      export GIO_EXTRA_MODULES="${pkgs.dconf.lib}/lib/gio/modules"
      key="org.gnome.desktop.interface color-scheme"
      # shellcheck disable=SC2086
      [ "$(gsettings get $key)" = "'$want'" ] || gsettings set $key "$want"
    '';
  };

  # output: relative to $HOME. livePreview: re-render while browsing the picker.
  apps = [
    { name = "ironbar"; template = "ironbar-theme.css"; output = "${stateRel}/ironbar.css"; livePreview = true; }
    { name = "niri"; template = "niri-theme.kdl"; output = "${stateRel}/niri.kdl"; livePreview = true; }
    { name = "wezterm"; template = "wezterm-theme.lua"; output = "${stateRel}/wezterm.lua"; livePreview = true; }
    { name = "btop"; template = "btop-theme.theme"; output = ".config/btop/themes/skwd-managed.theme"; livePreview = true; }
    { name = "mako"; template = "mako-theme.conf"; output = "${stateRel}/mako.conf"; livePreview = false; }
    { name = "fuzzel"; template = "fuzzel-theme.ini"; output = "${stateRel}/fuzzel.ini"; livePreview = false; }
    { name = "foot"; template = "foot-theme.ini"; output = "${stateRel}/foot.ini"; livePreview = false; }
  ];

  hookPath = name: "skwd-theme/hooks/${name}.sh";
  reloadFor = name: if hooks ? ${name} then "~/.config/${hookPath name}" else "";

  integrations =
    map (a: {
      inherit (a) name template livePreview;
      output = "~/${a.output}";
      reload = reloadFor a.name;
    }) apps
    ++ [
      { name = "gtk-mode"; template = ""; output = ""; reload = reloadFor "gtk-mode"; livePreview = false; }
    ];

  wantedJson = pkgs.writeText "skwd-integrations.json" (builtins.toJSON integrations);
  initialJson = pkgs.writeText "skwd-config.json" (builtins.toJSON { inherit integrations; });
  jq = "${pkgs.jq}/bin/jq";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  seedApp = a: ''
    if [ ! -e ${lib.escapeShellArg "${templatesDir}/${a.template}"} ]; then
      run install -Dm644 ${./templates + "/${a.template}"} ${lib.escapeShellArg "${templatesDir}/${a.template}"}
      skwdChanged=1
    fi
    if [ ! -e ${lib.escapeShellArg "${home}/${a.output}"} ]; then
      run install -Dm644 ${renderFallback a.name (builtins.readFile (./templates + "/${a.template}"))} ${lib.escapeShellArg "${home}/${a.output}"}
      skwdChanged=1
    fi
  '';
in
{
  xdg.configFile = lib.mapAttrs' (
    name: drv: lib.nameValuePair (hookPath name) { source = "${drv}/bin/skwd-theme-${name}"; }
  ) hooks;

  home.activation.skwdTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    skwdChanged=
    ${lib.concatMapStrings seedApp apps}

    skwdCfg=${lib.escapeShellArg configJson}
    if [ -L "$skwdCfg" ]; then
      warnEcho "skwd-theme: $skwdCfg is a symlink; skwd-wall needs a writable file. Not touching it."
    elif [ ! -e "$skwdCfg" ]; then
      run install -Dm644 ${initialJson} "$skwdCfg"
      skwdChanged=1
    elif ! skwdMissing=$(${jq} -c --slurpfile want ${wantedJson} '
        if type != "object" then error("not an object") else . end
        | (.integrations // []) as $have
        | if ($have | type) != "array" then error("integrations is not an array") else . end
        | [$have[] | (.name? | strings) // "" | ascii_downcase] as $names
        | [$want[0][] | select((.name | ascii_downcase) as $n | any($names[]; . == $n) | not)]
      ' "$skwdCfg" 2>/dev/null); then
      warnEcho "skwd-theme: $skwdCfg is not valid skwd JSON; leaving it alone."
    elif [ "$skwdMissing" != "[]" ]; then
      if [[ -v DRY_RUN ]]; then
        echo "Would add skwd-wall integrations: $skwdMissing"
      else
        skwdTmp=$(mktemp "$skwdCfg.XXXXXX")
        ${jq} --argjson add "$skwdMissing" '.integrations = ((.integrations // []) + $add)' \
          "$skwdCfg" > "$skwdTmp"
        chmod --reference="$skwdCfg" "$skwdTmp"
        mv "$skwdTmp" "$skwdCfg"
      fi
      skwdChanged=1
    fi

    if [ -n "$skwdChanged" ] \
      && XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
         ${systemctl} --user is-active --quiet graphical-session.target; then
      XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        run ${systemctl} --user try-restart skwd-walld.service \
        || warnEcho "skwd-theme: could not restart skwd-walld.service"
    fi
  '';
}
