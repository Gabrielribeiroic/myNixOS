{ self, ... }: {
  flake.nixosModules.prowlarr =
    { config, lib, ... }:
    {
      options.features.prowlarr = {
        enable = lib.mkEnableOption "Prowlarr indexer manager" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.prowlarr.enable {
        services.prowlarr = {
          enable = true;
          openFirewall = true; # WebUI 9696
        };
      };
    };
}
