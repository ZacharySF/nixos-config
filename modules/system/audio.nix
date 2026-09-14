# Audio: PipeWire (replaces PulseAudio and JACK).
{ ... }:
{
  services.pulseaudio.enable = false; # PipeWire provides the pulse interface instead
  security.rtkit.enable = true;       # lets audio threads get realtime priority

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit games / wine
    pulse.enable = true;      # PulseAudio-compatible socket
    wireplumber.enable = true; # session/policy manager
  };
}
