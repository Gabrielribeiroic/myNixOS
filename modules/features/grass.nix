{ ... }:
{
  flake.nixosModules.grass =
    { config, lib, pkgs, ... }:
    let
      grass = pkgs.stdenvNoCC.mkDerivation {
        pname = "grass-desktop";
        version = "7.6.0";
        src = pkgs.fetchurl {
          url = "https://files.grass.io/file/grass-extension-upgrades/v7.6.0/grass-desktop_7.6.0_amd64.deb";
          hash = "sha256-qo/sdQNr4gZiqOp6fUwdf75rYZVM3Z5LeqgCmlTsDBA=";
        };
        nativeBuildInputs = [ pkgs.dpkg pkgs.autoPatchelfHook ];
        buildInputs = with pkgs; [ gtk3 libappindicator-gtk3 webkitgtk_4_1 ];
        unpackPhase = "dpkg-deb -x $src .";
        installPhase = ''
          mkdir -p "$out"
          cp -r usr/* "$out/"
        '';
      };
    in
    {
      options.features.grass.enable = lib.mkEnableOption "Grass bandwidth-sharing client" // {
        default = false;
      };

      config = lib.mkIf config.features.grass.enable {
        environment.systemPackages = [ grass ];
        users.users.grass = {
          isSystemUser = true;
          group = "grass";
          home = "/var/lib/grass";
          createHome = true;
        };
        users.groups.grass = { };

        systemd.services.grass = {
          description = "Grass bandwidth-sharing desktop client";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            User = "grass";
            Group = "grass";
            StateDirectory = "grass";
            Environment = [ "HOME=/var/lib/grass" "DISPLAY=:0" ];
            ExecStart = "${grass}/bin/grass-desktop";
            Restart = "on-failure";
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
            MemoryMax = "768M";
            CPUQuota = "50%";
          };
        };
      };
    };
}
