{
  description = "NixOps configuration for nvvvu.org";

  inputs = {
    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
  };

  outputs = { self, nixpkgs, nixos-mailserver }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    packages.x86_64-linux.digital-ocean-image =
      with import nixpkgs { system = "x86_64-linux"; };
      (nixos {
        imports = [ (nixpkgs + "/nixos/modules/virtualisation/digital-ocean-image.nix") ];
      }).digitalOceanImage;

    packages.x86_64-linux.default = self.packages.x86_64-linux.digital-ocean-image;

    nixopsConfigurations.default = import ./vvvu.nix {
      pkgs = nixpkgs;
      nixos-mailserver = nixos-mailserver;
      keys = import ./keys.nix;
    };
  };
}
