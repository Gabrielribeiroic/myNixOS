{ self, inputs, ... }: {
  flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.homelabConfiguration
    ];
  };
}
