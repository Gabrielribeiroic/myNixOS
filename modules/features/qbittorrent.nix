{ self, ... }: {
  flake.nixosModules.qbittorrent =
    { config, lib, ... }:
    {
      options.features.qbittorrent = {
        enable = lib.mkEnableOption "qBittorrent BitTorrent client" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.qbittorrent.enable {
        services.qbittorrent = {
          enable = true;
          openFirewall = true; # opens WebUI 8080 + torrent port over TCP
          torrentingPort = 6881;
          group = "media"; # shared group: hardlink-safe rw across the stack
          serverConfig = {
            LegalNotice.Accepted = true;
            Preferences = {
              WebUI = {
                Username = "zep";
                Password_PBKDF2 = "@ByteArray(P9C6BY5mD/gF4ESGWbl5aA==:2Dp+2qpBm3C1epOrJyKNPCQUmT8fFIcVWXvuSp1mE7w1XccQo1cTzQaAGQzb5oorCgyPy8SZYp+fklXyNhQTng==)";
              };
              General.Locale = "en";
              Downloads = {
                SavePath = "/mnt/SKYHAWK00_4TB/Torrents";
                TempPath = "/mnt/SKYHAWK00_4TB/Torrents/.incomplete";
              };
              # new torrents are Auto-Managed -> saved under SavePath/<category>,
              # so Sonarr (category "tv") lands in Torrents/tv and Radarr in Torrents/movies
              BitTorrent.Session.DisableAutoTMMByDefault = false;
            };
          };
        };

        # DHT/PeX need UDP; nixpkgs' openFirewall only opens TCP
        networking.firewall.allowedUDPPorts = [ 6881 ];

        # downloads dir owned by the service user, group-writable by the stack
        systemd.tmpfiles.settings.qbittorrent = {
          "/mnt/SKYHAWK00_4TB/Torrents" = {
            d = {
              mode = "0775";
              user = "qbittorrent";
              group = "media";
            };
          };
        };

        systemd.services.qbittorrent = {
          # nixpkgs hardcodes 0022; group-write keeps qBittorrent/Sonarr/Radarr
          # able to read/delete each other's files (hardlinks + atomic moves)
          serviceConfig.UMask = lib.mkForce "0002";
        };
      };
    };
}
