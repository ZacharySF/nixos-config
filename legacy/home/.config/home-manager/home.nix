{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "xelo";
  home.homeDirectory = "/home/xelo";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.ironbar
    pkgs.swaybg
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
home.file = {
      ".config/ironbar/config.json".text = builtins.toJSON {
        position = "top";
        start = [
          {
            type = "clock";
            format = "%a %b %d  %I:%M %p";
          }
        ];
        end = [
          {
            type = "volume";
            format = "{icon} {percentage}%";
            icons = {
              volume_high = "󰕾";
              volume_medium = "󰖀";
              volume_low = "󰕿";
              muted = "󰝟";
            };
          }
          {
            type = "sys_info";
            format = [
              "  {cpu_percent}%"
              "  {memory_percent}%"
            ];
            interval = 5;
          }
          {
            type = "upower";
            format = "{icon} {percentage}%";
          }
        ];
      };

      ".config/ironbar/style.css".text = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          color: #c0caf5;
        }

        .background {
          background: #1a1b26;
        }

        #bar {
          border-bottom: 2px solid #292e42;
        }

        .widget {
          padding: 0 8px;
        }
      '';
    };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/xelo/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
