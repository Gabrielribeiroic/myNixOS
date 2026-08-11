{ self, ... }: {
  flake.nixosModules.radarr =
    { config, lib, ... }:
    {
      options.features.radarr = {
        enable = lib.mkEnableOption "Radarr movie manager" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.radarr.enable {
        services.radarr = {
          enable = true;
          openFirewall = true; # WebUI 7878
          group = "media"; # shared group: hardlink-safe rw across the stack
        };

        # media library dir owned by the shared media group
        systemd.tmpfiles.settings.radarr = {
          "/mnt/SKYHAWK00_4TB/Media/Movies" = {
            d = {
              mode = "0775";
              user = "root";
              group = "media";
            };
          };
        };

        systemd.services.radarr = {
          # nixpkgs hardcodes 0022; group-write keeps qBittorrent/Sonarr/Radarr
          # able to read/delete each other's files (hardlinks + atomic moves)
          serviceConfig.UMask = lib.mkForce "0002";
        };
      };
    };
}
