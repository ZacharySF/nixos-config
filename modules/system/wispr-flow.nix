# Wispr Flow — voice dictation that types into whatever window is focused
# (package: ../../pkgs/wispr-flow). Started hidden at login from
# home/niri/config.kdl; `wispr-flow --doctor` diagnoses input/clipboard access.
{ pkgs, ... }:
let
  wispr-flow = pkgs.callPackage ../../pkgs/wispr-flow { };
in
{
  environment.systemPackages = [ wispr-flow ];

  # The helper injects text through a /dev/uinput virtual keyboard.
  boot.kernelModules = [ "uinput" ];

  # Rule: /dev/uinput write (typing) + /dev/input/event* read (push-to-talk
  # hotkey), as group `input` 0660. Its logind `uaccess` ACL never lands here:
  # uinput is a static node with no udev event, so membership is what works.
  # Any of your processes can then read raw keyboard events — the price of a
  # global hotkey on Wayland.
  services.udev.packages = [ wispr-flow ];
  users.users.xelo.extraGroups = [ "input" ];
}
