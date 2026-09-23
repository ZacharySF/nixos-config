# Template for local-hardware.nix (gitignored, not tracked in this repo).
# Copy this to local-hardware.nix and fill in real values for this machine.
# AirPods routing now discovers connected devices at runtime in audio.nix.
# It does not depend on this file (Git flakes exclude gitignored files).
{
  airpodsMac = null; # e.g. "AA:BB:CC:DD:EE:FF" — `bluetoothctl devices`
}
