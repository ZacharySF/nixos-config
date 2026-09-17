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
        (
          # Draw immediately; repaint if Niri resizes during rendering.
          for ((attempt = 0; attempt < 3; attempt++)); do
            before_size=$(stty size 2>/dev/null)
            # Fit the usual 86-column tile even before Niri finishes sizing it.
            logo_width=52
            # Reserve 34 columns for the summary (the host line uses 33).
            read -r rows columns <<< "$before_size"
            if [[ $columns =~ ^[0-9]+$ ]] && ((columns < 86)); then
              logo_width=$((columns > 34 ? columns - 34 : 1))
            fi
            set -o pipefail
            fastfetch --config ~/.config/fastfetch/config.jsonc --pipe false --logo-width "$logo_width" |
              # Read pixel dimensions directly, without a WezTerm GUI round trip.
              # One streaming filter preserves the half-row gap and aligned colors.
              ${pkgs.perl}/bin/perl -e '
                $| = 1;
                my $image_height;
                if (open(my $tty, "<", "/dev/tty")) {
                  my $size = pack("S4", 0, 0, 0, 0);
                  if (ioctl($tty, 0x5413, $size)) { # Linux TIOCGWINSZ
                    my ($rows, $cols, $width, $height) = unpack("S4", $size);
                    $image_height = int($height / $rows * 22.5) if $rows && $height;
                  }
                }
                while (<STDIN>) {
                  if ($image_height) {
                    s/;height=23;/";height=" . $image_height . "px;"/e;
                    if (/\e\[40m/) {
                      s/\e\[4([0-7])m/\e[3$1m/g;
                      s/   /▄▄▄/g;
                    }
                    if (/\e\[100m/) {
                      s/\e\[10([0-7])m/\e[9$1m/g;
                      s/   /▀▀▀/g;
                    }
                  }
                  print;
                }
                print "\e[1A\r" if $image_height;
              ' || exit
            after_size=$(stty size 2>/dev/null)
            if [[ ! -t 0 || ! -t 1 || "$before_size" == "$after_size" ]] || ((attempt == 2)); then
              break
            fi
            # This is a new shell: only its partially rendered welcome is cleared.
            printf '\033[H\033[2J'
          done
        )
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
  xdg.configFile."fastfetch/misa2.png".source = ./fastfetch/misa2.png;

  # Nix store paths are immutable: refresh counts only when a profile changes.
  home.file.".local/bin/fastfetch-packages".source = pkgs.writeShellScript "fastfetch-packages" ''
    set -euo pipefail
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch"
    cache_file="$cache_dir/profile-counts"
    profiles=$(${pkgs.coreutils}/bin/readlink -f -- \
      /run/current-system /nix/var/nix/profiles/default \
      "$HOME/.nix-profile" "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile" \
      "/etc/profiles/per-user/$USER" 2>/dev/null || true)
    cache_key="${pkgs.fastfetch}:''${profiles//$'\n'/|}"
    if [[ -r $cache_file ]]; then
      { read -r cached_key; read -r counts; } < "$cache_file" || true
      if [[ ''${cached_key:-} == "$cache_key" && ''${counts:-} =~ ^[0-9]+\ sys,\ [0-9]+\ user$ ]]; then
        printf '%s\n' "$counts"
        exit
      fi
    fi
    counts=$(${pkgs.fastfetch}/bin/fastfetch --config none --structure packages --format json |
      ${pkgs.jq}/bin/jq -er '.[0].result | "\(.nixSystem // 0) sys, \(.nixUser // 0) user"')
    printf '%s\n' "$counts"
    if mkdir -p "$cache_dir"; then
      cache_tmp=$(mktemp "$cache_file.XXXXXX")
      trap 'rm -f "$cache_tmp"' EXIT
      printf '%s\n%s\n' "$cache_key" "$counts" > "$cache_tmp"
      mv "$cache_tmp" "$cache_file"
    fi
  '';

  # direnv + nix-direnv: drop a `.envrc` containing `use flake` in any project
  # and its dev shell loads automatically when you cd in. This is the main way
  # to get per-project quant/HDL toolchains without polluting your global env.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
