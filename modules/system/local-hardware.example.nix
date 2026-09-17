# Template for local-hardware.nix (gitignored, not tracked in this repo).
# Copy this to local-hardware.nix and fill in real values for this machine.
# With no local-hardware.nix present, modules fall back to `null` and the
# features that depend on these values (e.g. the AirPods auto-default
# service in audio.nix) are simply disabled.
{
  airpodsMac = null; # e.g. "AA:BB:CC:DD:EE:FF" — `bluetoothctl devices`
}
