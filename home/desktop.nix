# User-level desktop bits that are not tied to one specific app:
# GTK theme, cursor theme, XDG user directories.
{ pkgs, ... }:
{
  # Firefox is installed system-wide (modules/system/desktop.nix); this just
  # manages profile prefs. Site isolation (Fission) spawns a fresh content
  # process pretty liberally by default — cap the pool so it reuses processes
  # across same-site tabs instead of growing unbounded. Cross-origin isolation
  # is unaffected.
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "dom.ipc.processCount" = 4;
        "browser.tabs.unloadOnLowMemory" = true;
        # Transparent Firefox guide: Linux/Wayland, with CSS loaded at startup.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.allow_transparent_browser" = true;
        "layout.css.prefers-color-scheme.content-override" = 0;
        "mozilla.widget.use-argb-visuals" = true;
        "browser.tabs.inTitlebar" = 1;
      };
      userChrome = ''
        :root {
          --ft-tint: rgba(18, 18, 26, 0.35);
          --ft-surface: rgba(255, 255, 255, 0.08);
          --ft-selected: rgba(255, 255, 255, 0.16);
          --ft-solid: rgba(28, 28, 36, 0.94);
          --toolbox-background-color: transparent !important;
          --toolbox-background-color-inactive: transparent !important;
          --toolbox-background-image: none !important;
          --toolbar-background-color: transparent !important;
          --tabpanel-background-color: transparent !important;
          --sidebar-background-color: transparent !important;
          --lwt-accent-color: transparent !important;
          --lwt-accent-color-inactive: transparent !important;
          --chrome-content-separator-color: transparent !important;
          --tabs-navbar-separator-color: transparent !important;
          --content-area-shadow: none !important;
          --tab-background-color-selected: var(--ft-selected) !important;
          --toolbar-field-background-color: var(--ft-surface) !important;
          --toolbar-field-background-color-focus: var(--ft-solid) !important;
        }
        :root, #main-window {
          background: transparent !important;
        }
        body, body:-moz-window-inactive {
          background: var(--ft-tint) !important;
        }
        #navigator-toolbox, #TabsToolbar, #nav-bar, #PersonalToolbar,
        #titlebar, #browser, #tabbrowser-tabbox, #tabbrowser-tabpanels,
        .browserContainer, .browserStack, #sidebar-main, #sidebar-box,
        #sidebar-box #sidebar, #sidebar-header, #vertical-tabs {
          background: transparent !important;
          border-color: transparent !important;
          box-shadow: none !important;
        }
        browser[transparent="true"],
        #tabbrowser-tabpanels browser[type="content"] {
          background: none !important;
        }
        .tab-background:is([selected], [multiselected]) {
          box-shadow: none !important;
        }
        #urlbar[open] > .urlbar-background,
        #urlbar[open] > #urlbar-background,
        #statuspanel-label {
          background-color: var(--ft-solid) !important;
        }
      '';
      userContent = ''
        @-moz-document url("about:newtab"), url("about:home"),
          url("about:blank"), url("about:privatebrowsing") {
          :root, body, .outer-wrapper, .activity-stream {
            --newtab-background-color: transparent !important;
            --newtab-background-color-secondary: rgba(255, 255, 255, 0.08) !important;
            --background-color-canvas: transparent !important;
            --in-content-page-background: transparent !important;
            background: transparent !important;
          }
        }
      '';
    };
  };

  # Keep the signed AMO add-on reproducible without adding another flake input.
  # Runtime settings/style cache remain mutable so site exceptions survive rebuilds.
  home.file.".mozilla/firefox/default/extensions/{91aa3897-2634-4a8a-9092-279db23a7689}.xpi" = {
    source = pkgs.fetchurl {
      url = "https://addons.mozilla.org/firefox/downloads/file/4854703/zen_internet-3.2.0.xpi";
      hash = "sha256-eEEOh3J3kT8Zvc34yhOOCN/3WP2LntmdZ8UmgeWB/Rk=";
    };
    force = true;
  };

  # Consistent dark GTK look for nautilus, pavucontrol, etc.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  # Nautilus and other GTK4/libadwaita apps ignore gtk.theme above and follow
  # org.gnome.desktop.interface color-scheme instead. skwd-wall's "gtk-mode"
  # hook (home/skwd-theme) sets it from each wallpaper's light/dark palette, so
  # it is deliberately not pinned here.

  # Cursor theme (also exported to the Wayland/XCURSOR env).
  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
  };

  gtk.gtk4.theme = null; # adopt new default (no gtk4 theme override)

  # Lowercase home folders; keep application defaults aligned with existing paths.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false; # adopt new default
    desktop = "/home/xelo/desktop";
    documents = "/home/xelo/documents";
    download = "/home/xelo/downloads";
    music = "/home/xelo/music";
    pictures = "/home/xelo/pictures";
    publicShare = "/home/xelo/public";
    templates = "/home/xelo/templates";
    videos = "/home/xelo/videos";
    extraConfig.XDG_PROJECTS_DIR = "/home/xelo/projects";
  };

  # A couple of GUI utilities that belong to "the desktop" rather than dev work.
  home.packages = with pkgs; [
    anki           # spaced-repetition flashcards
    chromium       # web browser
    tor-browser    # anonymous browsing; no system tor service/proxy involved
    nautilus       # file manager
    pavucontrol    # audio mixer
    wezterm       # terminal emulator
    wl-clipboard
    libreoffice    # opens .docx/.doc/.odt/.xlsx/.pptx and more
  ];
}
