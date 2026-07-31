{ self, inputs, ... }:
{
  flake.nixosConfigurations.vps = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.disko.nixosModules.disko
      self.nixosModules.vpsConfiguration
    ];
  };
}
