# Aggregates every system-level module. `hosts/*/default.nix` imports this one
# directory and gets all of it.
{ ... }:
{
  imports = [
    ./nix.nix
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./audio.nix
    ./desktop.nix
    ./users.nix
    ./packages.nix
  ];
}
