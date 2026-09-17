# Existing NixOS installation on the internal NVMe drive, alongside Windows.
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ../../modules/system ];
  networking.hostName = "xelo-nixos-main";
  system.stateVersion = "25.11";
  users.users.xelo.uid = 1001;

  # Prefer compressed RAM swap, with the existing disk swap as fallback.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # Shared 384 MiB Windows ESP. Preserve firmware boot order and show the menu.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 2;
  boot.loader.timeout = 5;

  home-manager.users.xelo.programs.bash.shellAliases = {
    rebuild = lib.mkForce "sudo nixos-rebuild switch --flake ~/nixos-config#xelo-nixos-main";
    rebuild-test = lib.mkForce "sudo nixos-rebuild test --flake ~/nixos-config#xelo-nixos-main";
    rebuild-check = lib.mkForce "nixos-rebuild build --flake ~/nixos-config#xelo-nixos-main";
  };
}
