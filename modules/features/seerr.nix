{ self, ... }: {
  flake.nixosModules.seerr =
    { config, lib, ... }:
    {
      options.features.seerr = {
        enable = lib.mkEnableOption "Seerr media request manager" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.seerr.enable {
        services.seerr = {
          enable = true;
          openFirewall = true; # WebUI 5055
        };
      };
    };
}
