# User accounts and account-level features (docker, nix-ld).
{ pkgs, ... }:
{
  # Primary user. Set the password once with `sudo passwd xelo` on a fresh
  # machine (passwords are NOT stored in this repo).
  users.users.xelo = {
    isNormalUser = true;
    description = "xelo";
    extraGroups = [
      "wheel"          # sudo
      "networkmanager" # manage wifi without sudo
      "docker"         # talk to the docker daemon
      "video"          # brightnessctl / backlight
    ];
  };

  # Secondary low-privilege account for running AI / agent tooling in a bit of
  # isolation from your real home directory. It has NO password (cannot log in
  # until you run `sudo passwd aibox`) and is not in `wheel`.
  users.users.aibox = {
    isNormalUser = true;
    description = "AI Sandbox";
    home = "/home/aibox";
    shell = pkgs.bash;
    extraGroups = [ "networkmanager" ];
  };

  # Docker daemon (used by the `axon` project's docker-compose, etc).
  # enableOnBoot = false: don't run dockerd/containerd (~170MB idle) on every
  # boot. The docker.socket unit still socket-activates the daemon the moment
  # anything talks to the docker socket (`docker ps`, compose, etc) — no
  # workflow change, just no baseline cost on days Docker isn't touched.
  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;

  # nix-ld: provides a dynamic loader so pre-built binaries that are not
  # packaged for Nix (pip wheels, `rustup` toolchains, downloaded editors,
  # language servers) can still run.
  programs.nix-ld.enable = true;
}
