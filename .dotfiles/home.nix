{ config, pkgs, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  home.username = "xelo";
  home.homeDirectory = "/home/xelo";
  home.stateVersion = "25.11";

  systemd.user.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    ironbar
    fastfetch
    vesktop
    zed-editor-fhs
    pnpm
    gemini-cli
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/.dotfiles#xelo-nixos";
    };
    initExtra = ''
      PS1='\[\e[38;2;122;162;247m\]\u@\h:\w\$ \[\e[0m\]'
      fastfetch --structure Title:Separator:OS:Kernel:Shell:Terminal:Host:Uptime:Battery:WM:CPU:GPU:Memory:Disk:Swap:Separator:Break:Colors
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$HOME/.npm-global/bin:$PATH"
    '';
  };

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
