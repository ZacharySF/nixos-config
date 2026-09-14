# Bootloader, kernel, firmware.
{ pkgs, ... }:
{
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
