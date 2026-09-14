# System-wide packages.
#
# Keep this list SHORT. Only put things here that must exist for every user,
# for root, and in rescue situations (before your home environment loads).
# Everything else — editors, dev tools, apps — lives in ../../home/.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    micro   # friendly terminal editor; also NixOS's fallback $EDITOR
    wget
    curl
    btop    # system monitor (also usable from a TTY if the GUI breaks)
    pciutils
    usbutils
  ];
}
