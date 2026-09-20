# Networking, Bluetooth, SSH, VPN, firewall.
{ ... }:
{
  # NetworkManager handles wifi/ethernet. `nmtui` or the ironbar applet drive it.
  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true;    # exposes battery levels of connected devices
      FastConnectable = true; # quicker reconnect to known devices
    };
  };

  # Without an agent registered, bluetoothd has nobody to ask for
  # authorization and silently rejects reconnects from paired devices
  # ("Authentication attempt without agent" in the logs). Blueman runs one
  # persistently in the background (plus a tray icon).
  services.blueman.enable = true;

  # AmneziaVPN — GUI client plus the privileged helper it needs.
  programs.amnezia-vpn.enable = true;

  # SSH server. Password login is left on because there are currently no keys
  # enrolled; once you add a key to ~/.ssh/authorized_keys, flip this to false.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # Default-deny firewall. Add ports here if you ever need to serve something:
  #   networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.enable = true;
}
