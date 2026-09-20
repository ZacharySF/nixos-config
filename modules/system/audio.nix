# Audio: PipeWire (replaces PulseAudio and JACK).
{ pkgs, lib, ... }:
let
  # Gitignored, machine-specific — see local-hardware.example.nix. Falls back
  # to `null` (feature disabled) when no local-hardware.nix is present.
  localHardware =
    if builtins.pathExists ./local-hardware.nix
    then import ./local-hardware.nix
    else import ./local-hardware.example.nix;
in
{
  services.pulseaudio.enable = false; # PipeWire provides the pulse interface instead
  security.rtkit.enable = true;       # lets audio threads get realtime priority

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit games / wine
    pulse.enable = true;      # PulseAudio-compatible socket
    wireplumber.enable = true; # session/policy manager

    wireplumber.extraConfig."51-bluez-no-aac" = {
      # The AAC codec's bluez/PipeWire implementation is unstable on Linux and
      # periodically crashes the Bluetooth transport ("connection terminated
      # unexpectedly"), which drops the sink to muted/non-default until it's
      # manually fixed. Force SBC-XQ (high quality, no AAC's glitches) instead.
      #
      # Also disable AVRCP "hardware" volume: PipeWire's default is to forward
      # volume-slider changes to the device over AVRCP instead of applying
      # software gain, assuming the device will honor them. AirPods accept the
      # AVRCP command but don't actually change their output level from it on
      # Linux, so the volume slider/keys visibly move but nothing is audible
      # except mute. Setting hw-volume to an empty list forces WirePlumber to
      # always apply the gain itself instead of delegating to the device.
      #
      # This has to be `monitor.bluez.properties` (applied once, globally, when
      # the bluez5 backend registers its local A2DP codec endpoints with BlueZ)
      # rather than a per-device `monitor.bluez.rules` match: this is endpoint
      # registration, not a per-device runtime property, so a rules-based
      # update-props on an already-connected device is silently a no-op — it
      # updates the metadata but doesn't change how the endpoint was registered.
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [ "sbc_xq" "sbc" ];
        "bluez5.enable-sbc-xq" = true;
        "bluez5.hw-volume" = [ ];
      };
    };
  };

  # WirePlumber only auto-picks a device as the default sink the first time
  # it's ever seen; after that, whichever sink was last explicitly selected
  # stays "sticky" even when a higher-priority device (like the AirPods)
  # reconnects later, e.g. after boot before Bluetooth has reconnected. That's
  # why the AirPods can be connected but audio still plays from the laptop
  # speakers. This watches for the AirPods Pro sink appearing and forces it
  # back to being the default output whenever that happens.
  systemd.user.services.airpods-auto-default = lib.mkIf (localHardware.airpodsMac != null) {
    description = "Auto-select AirPods Pro as default audio output when connected";
    wantedBy = [ "pipewire.service" ];
    after = [ "pipewire.service" "wireplumber.service" ];
    serviceConfig = {
      ExecStart =
        let
          script = pkgs.writeShellApplication {
            name = "airpods-auto-default";
            runtimeInputs = [
              pkgs.wireplumber
              pkgs.pipewire
              pkgs.jq
              pkgs.gnugrep
            ];
            text = ''
              MAC="${localHardware.airpodsMac}"
              while true; do
                target_id=$(pw-dump | jq -r --arg mac "$MAC" '
                  .[] | select(.type=="PipeWire:Interface:Node")
                  | select(.info.props["media.class"]? == "Audio/Sink")
                  | select(.info.props["api.bluez5.address"]? == $mac)
                  | .id' | head -n1)

                if [ -n "$target_id" ]; then
                  current_addr=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
                    | grep -oP 'api\.bluez5\.address = "\K[^"]+' || true)
                  if [ "$current_addr" != "$MAC" ]; then
                    wpctl set-default "$target_id"
                  fi
                fi
                sleep 3
              done
            '';
          };
        in
        "${script}/bin/airpods-auto-default";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
