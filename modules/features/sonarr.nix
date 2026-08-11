{ self, ... }: {
  flake.nixosModules.sonarr =
    { config, lib, ... }:
    {
      options.features.sonarr = {
        enable = lib.mkEnableOption "Sonarr TV series manager" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.sonarr.enable {
        services.sonarr = {
          enable = true;
          openFirewall = true; # WebUI 8989
          group = "media"; # shared group: hardlink-safe rw across the stack
        };

        systemd.services.sonarr = {
          # nixpkgs hardcodes 0022; group-write keeps qBittorrent/Sonarr/Radarr
          # able to read/delete each other's files (hardlinks + atomic moves)
          serviceConfig.UMask = lib.mkForce "0002";
        };
      };
    };
}
