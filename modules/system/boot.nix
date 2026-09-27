# Bootloader, kernel, firmware.
{ config, lib, pkgs, ... }:
{
  # Both hosts describe this laptop, but different installations. Reject a
  # mismatched root or ESP before switch-to-configuration touches services or
  # the bootloader. Builds remain possible for either host on either drive.
  system.preSwitchChecks.installationDisks = ''
    # nixos-install in a fresh chroot has no running system to compare with.
    if [ ! -e /run/current-system ]; then
      exit 0
    fi
    ${lib.concatMapStringsSep "\n" (mountPoint: let
      expectedUUID = lib.removePrefix "/dev/disk/by-uuid/" config.fileSystems.${mountPoint}.device;
    in ''
      actual_uuid=$(${pkgs.util-linux}/bin/findmnt --noheadings --output UUID --mountpoint ${lib.escapeShellArg mountPoint})
      if [ "$actual_uuid" != ${lib.escapeShellArg expectedUUID} ]; then
        echo ${lib.escapeShellArg "Refusing to activate ${config.networking.hostName}: ${mountPoint} must have UUID ${expectedUUID}. Select the flake host for the mounted installation."} >&2
        exit 1
      fi
    '') [ "/" "/boot" ]}
  '';

  # systemd-boot: simple UEFI bootloader. The menu at startup lists every
  # generation, so a bad rebuild is always one reboot away from being undone.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 20; # cap boot menu entries

  # Track the latest stable kernel rather than the (older) LTS default.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Ship redistributable firmware blobs (wifi, bluetooth, audio DSP...).
  hardware.enableAllFirmware = true;
  hardware.firmware = [ pkgs.sof-firmware ]; # Intel "Sound Open Firmware" for the laptop mic/speakers
}
