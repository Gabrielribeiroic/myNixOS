{ self, ... }: {

  flake.nixosModules.legion = { config, pkgs, ... }: {
    boot.kernelModules = [ 
      "ideapad_laptop" 
    ];
  };
}
