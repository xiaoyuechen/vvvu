{
  description = "NixOps configuration for nvvvu.org";

  inputs = {
    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
  };

  outputs = { self, nixpkgs, nixos-mailserver }:
    let pkgs = import nixpkgs { system = "x86_64-linux"; }; in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      packages.x86_64-linux.digital-ocean-image =
        (pkgs.nixos {
          imports = [ (nixpkgs + "/nixos/modules/virtualisation/digital-ocean-image.nix") ];
        }).digitalOceanImage;

      packages.x86_64-linux.default = self.packages.x86_64-linux.digital-ocean-image;

      devShells.x86_64-linux.default = with pkgs; mkShell {
        packages = [ nixops_unstable_minimal ];
      };

      nixopsConfigurations.default = import ./vvvu.nix {
        inherit nixpkgs;
        nixos-mailserver = nixos-mailserver;
        keys = import ./keys.nix;
      };
    };
}
