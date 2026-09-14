# Nix daemon settings, garbage collection, and unfree policy.
{ inputs, ... }:
{
  nixpkgs.config.allowUnfree = true; # vscode, obsidian, discord, spotify, nvidia blobs...

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true; # hardlink identical files in the store to save disk
    # Anyone in `wheel` can add binary caches / do trusted operations.
    trusted-users = [ "root" "@wheel" ];
  };

  # Automatic garbage collection so the disk does not slowly fill with old
  # generations. `nixos-rebuild` always keeps the current + previous few.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 21d";
  };

  # Make `nix run nixpkgs#foo`, `nix-shell -p foo`, and `<nixpkgs>` all resolve
  # to the exact nixpkgs this flake is locked to (instead of a stale channel).
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
}
