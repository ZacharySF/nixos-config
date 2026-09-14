{
  description = "xelo's NixOS configuration — single host: xelo-nixos (Intel laptop, Niri/Wayland)";

  inputs = {
    # nixpkgs — the package set. `nixos-unstable` is a rolling branch that is
    # still gated by CI, so it is reasonably safe day to day.
    #
    # The committed flake.lock pins reproducible package revisions. Move it forward
    # with `nix flake update` whenever you want newer packages.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager — manages everything inside $HOME (dotfiles, user packages).
    # `.follows` makes it use the SAME nixpkgs as the system, so there is only
    # ever one version of every library in the closure.
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # spicetify-nix — declarative Spotify (spicetify) theming.
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, home-manager, spicetify-nix, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      # `sudo nixos-rebuild switch --flake ~/nixos-config#xelo-nixos`
      nixosConfigurations.xelo-nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        # Makes `inputs` available to every module via its argument set.
        specialArgs = { inherit inputs; };

        modules = [
          # ---- The machine ----
          ./hosts/xelo-nixos

          # ---- home-manager wired in as a NixOS module ----
          # This means ONE command (`nixos-rebuild switch`) builds both the
          # system and the user environment. No separate `home-manager switch`.
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;      # share the system nixpkgs
            home-manager.useUserPackages = true;    # install into /etc/profiles
            home-manager.backupFileExtension = "hm-backup"; # rename clashing files instead of failing
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.xelo = import ./home;
            home-manager.sharedModules = [ spicetify-nix.homeManagerModules.default ];
          }
        ];
      };

      # `nix fmt` formats every .nix file in the repo.
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
