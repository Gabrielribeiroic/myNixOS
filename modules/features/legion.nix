{ self, ... }: {

  flake.nixosModules.legion = { config, pkgs, ... }: {
    boot.extraModulePackages = with config.boot.kernelPackages; [ 
      lenovo-legion-module
    ];

    boot.kernelModules = [ 
      "lenovo-legion"
      "ideapad_laptop" 
    ];

    environment.systemPackages = with pkgs; [
      lenovo-legion
    ];
  };
}
