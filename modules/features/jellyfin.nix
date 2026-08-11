{ self, ... }: {
  flake.nixosModules.jellyfin =
    { config, lib, ... }:
    {
      options.features.jellyfin = {
        enable = lib.mkEnableOption "Jellyfin media server" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.jellyfin.enable {
        services.jellyfin = {
          enable = true;
          openFirewall = true; # 8096
          group = "media"; # read (and delete) access to the media library
        };
      };
    };
}
