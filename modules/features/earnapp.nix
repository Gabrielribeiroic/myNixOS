{ ... }:
{
  flake.nixosModules.earnapp =
    { config, lib, pkgs, ... }:
    let
      earnapp = pkgs.stdenvNoCC.mkDerivation {
        pname = "earnapp";
        version = "1.651.510";
        src = pkgs.fetchurl {
          url = "https://cdn-earnapp.b-cdn.net/static/earnapp-x64-1.651.510";
          hash = "sha256-nUOnNQCMAJ+zMInvqBrzKrguh6rbf6ncTzI0aDEABx4=";
        };
        dontUnpack = true;
        installPhase = ''
          install -Dm755 "$src" "$out/bin/earnapp"
        '';
      };
    in
    {
      options.features.earnapp.enable = lib.mkEnableOption "EarnApp bandwidth-sharing client" // {
        default = false;
      };

      config = lib.mkIf config.features.earnapp.enable {
        environment.systemPackages = [ earnapp ];
        users.users.earnapp = {
          isSystemUser = true;
          group = "earnapp";
          home = "/var/lib/earnapp";
          createHome = true;
        };
        users.groups.earnapp = { };

        systemd.services.earnapp = {
          description = "EarnApp bandwidth-sharing client";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "earnapp";
            Group = "earnapp";
            StateDirectory = "earnapp";
            Environment = [
              "HOME=/var/lib/earnapp"
              "XDG_CONFIG_HOME=/var/lib/earnapp"
            ];
            ExecStart = "${earnapp}/bin/earnapp start";
            ExecStop = "${earnapp}/bin/earnapp stop";
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryMax = "512M";
            CPUQuota = "50%";
          };
        };
      };
    };
}
