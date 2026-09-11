{ self, ... }: {
  flake.nixosModules.crafty =
    { config, lib, pkgs, ... }:
    {
      options.features.crafty.enable = lib.mkEnableOption "Crafty Controller Minecraft server management panel" // {
        default = false;
      };

      config = lib.mkIf config.features.crafty.enable {
        # Enable Podman
        virtualisation.podman.enable = true;

        # Crafty container
        virtualisation.oci-containers = {
          backend = "podman";
          containers.crafty = {
            image = "registry.gitlab.com/crafty-controller/crafty-4:4.10.8";
            autoStart = true;
            ports = [
              "127.0.0.1:8443:8443" # HTTPS panel, loopback only (traefik proxies)
              "25500-25600:25500-25600" # Java server port pool, public
            ];
            volumes = [
              "/var/lib/crafty/servers:/crafty/servers"
              "/var/lib/crafty/backups:/crafty/backups"
              "/var/lib/crafty/logs:/crafty/logs"
              "/var/lib/crafty/config:/crafty/app/config"
              "/var/lib/crafty/import:/crafty/import"
            ];
          };
        };

        # Data directory
        systemd.tmpfiles.rules = [
          "d /var/lib/crafty 0755 root root -"
          "d /var/lib/crafty/servers 0755 root root -"
          "d /var/lib/crafty/backups 0755 root root -"
          "d /var/lib/crafty/logs 0755 root root -"
          "d /var/lib/crafty/config 0755 root root -"
          "d /var/lib/crafty/import 0755 root root -"
        ];

        # traefik: public HTTPS entrypoint + Let's Encrypt for crafty.zephiron.uk
        services.traefik = {
          enable = true;
          staticConfigOptions = {
            entryPoints.http.address = ":80";
            entryPoints.websecure.address = ":443";
            certificatesResolvers.le.acme.email = "ic.gabrielribeiro@gmail.com";
            certificatesResolvers.le.acme.storage = "/var/lib/traefik/acme.json";
            certificatesResolvers.le.acme.httpChallenge.entryPoint = "http";
          };
          dynamicConfigOptions.http = {
            serversTransports.crafty.insecureSkipVerify = true;
            services.crafty.loadBalancer = {
              serversTransport = "crafty";
              servers = [
                { url = "https://127.0.0.1:8443"; }
              ];
            };
            middlewares.crafty-redirect.redirectScheme = {
              scheme = "https";
              permanent = true;
            };
            routers.crafty = {
              entryPoints = [ "websecure" ];
              rule = "Host(`crafty.zephiron.uk`)";
              service = "crafty";
              tls.certresolver = "le";
            };
            routers.crafty-http = {
              entryPoints = [ "http" ];
              rule = "Host(`crafty.zephiron.uk`)";
              middlewares = [ "crafty-redirect" ];
              service = "crafty";
            };
          };
        };

        # Firewall: ACME + HTTPS + Minecraft game pool
        networking.firewall = {
          allowedTCPPorts = [ 80 443 ];
          allowedTCPPortRanges = [
            { from = 25500; to = 25600; }
          ];
        };
      };
    };
}
