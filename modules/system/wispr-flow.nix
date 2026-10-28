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

  # Grants the logged-in user /dev/uinput write + /dev/input/event* read (the
  # global push-to-talk hotkey). Note: any process in your session can then
  # read raw keyboard events — the price of a global hotkey on Wayland.
  services.udev.packages = [ wispr-flow ];
}
