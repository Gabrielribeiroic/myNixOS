{ self, inputs, ... }:
{
  perSystem = { system, ... }: {
    packages.colmena = inputs.colmena.packages.${system}.colmena;
  };

  flake.colmenaHive = inputs.colmena.lib.makeHive {
    meta.nixpkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
    };

    vps = {
      imports = [
        inputs.disko.nixosModules.disko
        self.nixosModules.vpsConfiguration
      ];

      deployment = {
        targetHost = "164.152.53.60";
        targetUser = "zep";
        buildOnTarget = true;
        tags = [ "oracle" "vps" ];
      };
    };
  };
}
