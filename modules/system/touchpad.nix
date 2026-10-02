# Workaround for the built-in Elan touchpad (VEN_04F3:00 04F3:3330, i2c-hid)
# on the Dell 14 Plus 2-in-1 periodically wedging: the kernel logs
# "i2c_hid_get_input: incomplete report" / libinput logs "Touch jump detected
# and discarded", and the cursor stops responding until the device is
# re-initialised. It's a firmware/driver quirk with no libinput-side fix, so
# instead we make re-initialising it cheap and automatic:
#
#   * touchpad-reset.service unbinds + rebinds the i2c_hid_acpi driver, which
#     power-cycles and resets the touchpad (~1s, no reboot).
#   * It runs automatically after every suspend/hibernate resume.
#   * The user can trigger it on demand without a password (polkit rule
#     below) — bound to Mod+Alt+T in home/niri/config.kdl, or run
#     `touchpad-reset` from a terminal.
{ pkgs, ... }:
let
  device = "i2c-VEN_04F3:00";
  driver = "/sys/bus/i2c/drivers/i2c_hid_acpi";

  resetScript = pkgs.writeShellScript "touchpad-reset-root" ''
    set -u
    if [ ! -e /sys/bus/i2c/devices/${device} ]; then
      echo "touchpad ${device} not present, nothing to do"
      exit 0
    fi
    if [ -e ${driver}/${device} ]; then
      echo -n ${device} > ${driver}/unbind
      sleep 0.5
    fi
    echo -n ${device} > ${driver}/bind
    echo "touchpad ${device} re-initialised"
  '';

  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  systemd.services.touchpad-reset = {
    description = "Re-initialise the Elan i2c-hid touchpad";
    # Pulled in when any sleep target is reached; `after` makes it run once
    # the system has actually resumed.
    wantedBy = sleepTargets;
    after = sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = resetScript;
    };
  };

  # Let the desktop user start/restart just this one unit without a password.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "touchpad-reset.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "restart") &&
          subject.user == "xelo") {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "touchpad-reset" ''
      exec systemctl start touchpad-reset.service
    '')
  ];
}
