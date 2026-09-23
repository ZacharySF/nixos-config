# Audio: PipeWire (replaces PulseAudio and JACK).
{ pkgs, ... }:
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

  # Select AirPods once when their playback node appears, including after a
  # reconnect or audio-service restart. Remember the node serial so manual
  # output changes still work until the next connection. Discover the device
  # at runtime: Git flakes exclude the gitignored local-hardware.nix file,
  # which previously caused this service to disappear from system builds.
  #
  # Also self-heals mute/zero-volume: despite the SBC-XQ fix above, a fresh
  # A2DP connection (or a mid-session transport hiccup) can still hand back a
  # node that's muted or at 0% — silent audio with everything otherwise
  # "working". Checked on every loop tick (not just on reconnect) so it
  # recovers even if this happens mid-session, not only at initial connect.
  systemd.user.services.airpods-auto-default = {
    description = "Auto-select AirPods as default audio output when connected";
    wantedBy = [ "pipewire.service" ];
    after = [ "pipewire.service" "wireplumber.service" ];
    partOf = [ "pipewire.service" ];
    serviceConfig = {
      ExecStart =
        let
          script = pkgs.writeShellApplication {
            name = "airpods-auto-default";
            runtimeInputs = [
              pkgs.wireplumber
              pkgs.pipewire
              pkgs.jq
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gawk
            ];
            text = ''
              previous_serial=""
              while true; do
                # A timeout or a disappearing node is normal during reconnects.
                if ! snapshot=$(timeout 5 pw-dump); then
                  sleep 3
                  continue
                fi
                target=$(jq -r '
                  [.[] | select(.type == "PipeWire:Interface:Node")
                  | select(.info.props["media.class"] == "Audio/Sink")
                  | select(.info.props["device.api"] == "bluez5")
                  | select((.info.props["node.description"] // "")
                      | test("airpods"; "i"))]
                  | sort_by(.info.props["object.serial"] | tonumber)
                  | last
                  | if . == null then ""
                    else "\(.id) \(.info.props["object.serial"])" end
                ' <<< "$snapshot")

                if [ -z "$target" ]; then
                  previous_serial=""
                else
                  read -r target_id target_serial <<< "$target"
                  if [ "$target_serial" != "$previous_serial" ]; then
                    if wpctl set-default "$target_id"; then
                      previous_serial="$target_serial"
                      echo "Selected AirPods output (node $target_id)"
                    fi
                  fi

                  vol_line=$(wpctl get-volume "$target_id" 2>/dev/null || true)
                  vol_num=$(grep -oP '[0-9]+\.[0-9]+' <<< "$vol_line" | head -n1 || true)
                  if grep -q MUTED <<< "$vol_line" \
                    || [ -z "$vol_num" ] \
                    || awk -v n="$vol_num" 'BEGIN { exit !(n < 0.05) }'; then
                    wpctl set-mute "$target_id" 0
                    wpctl set-volume "$target_id" 0.60
                    echo "Restored AirPods volume (was: ''${vol_line:-unknown})"
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
