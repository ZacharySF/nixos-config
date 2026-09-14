# Interactive shell: bash config, prompt, core CLI tools, direnv.
{ pkgs, ... }:
{
  programs.bash = {
    enable = true;

    shellAliases = {
      # Rebuild the system from this repo.
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#xelo-nixos";
      # Build + activate WITHOUT adding a boot entry (reverts on reboot). Good
      # for testing risky changes.
      rebuild-test = "sudo nixos-rebuild test --flake ~/nixos-config#xelo-nixos";
      # Just evaluate/build, do not touch the running system.
      rebuild-check = "nixos-rebuild build --flake ~/nixos-config#xelo-nixos";
      # Pull newer nixpkgs/home-manager (updates flake.lock).
      update = "nix flake update --flake ~/nixos-config";
      # Format all nix files.
      nixfmt = "nix fmt ~/nixos-config";

      ".." = "cd ..";
      "..." = "cd ../..";
    };

    initExtra = ''
      # blue user@host:path prompt
      PS1='\[\e[38;2;122;162;247m\]\u@\h:\w\$ \[\e[0m\]'

      # system summary on new interactive shells
      if [[ $- == *i* ]] && command -v fastfetch >/dev/null; then
        fastfetch --config ~/.config/fastfetch/config.jsonc
      fi
    '';
  };

  # Core command-line tools that follow you everywhere.
  home.packages = with pkgs; [
    fastfetch  # the startup system summary
    ripgrep    # `rg` — fast grep
    fd         # fast find
    fzf        # fuzzy finder
    jq         # JSON on the command line
    tree
    wl-clipboard # `wl-copy` / `wl-paste` under Wayland
    unzip
    file
  ];

  xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch.jsonc;

  # direnv + nix-direnv: drop a `.envrc` containing `use flake` in any project
  # and its dev shell loads automatically when you cd in. This is the main way
  # to get per-project quant/HDL toolchains without polluting your global env.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
