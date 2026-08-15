{ self, ... }: {
  flake.nixosModules.tuya-pc-power =
    { config, lib, pkgs, ... }:
    let
      inherit (config.sops.secrets)
        tuya_ip
        tuya_device_id
        tuya_local_key
        ;
    in
    {
      options.features.tuya-pc-power = {
        enable = lib.mkEnableOption "local control daemon for the Tuya PCIe power relay" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.tuya-pc-power.enable {
        sops.secrets = {
          tuya_ip.sopsFile = ../../secrets/tuya.yaml;
          tuya_device_id.sopsFile = ../../secrets/tuya.yaml;
          tuya_local_key.sopsFile = ../../secrets/tuya.yaml;
        };

        # Reachable from phone/other hosts over Tailscale only; n8n on this
        # box uses localhost. Nothing is exposed to the LAN/Internet.
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8090 ];

        systemd.services.tuya-relay = {
          description = "Local control daemon for the Tuya PCIe power relay";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.python3.withPackages (ps: [ ps.tinytuya ])}/bin/python ${../../assets/tuya_relay.py}";
            Restart = "on-failure";
            DynamicUser = true;
            LoadCredential = [
              "tuya_ip:${tuya_ip.path}"
              "tuya_device_id:${tuya_device_id.path}"
              "tuya_local_key:${tuya_local_key.path}"
            ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
          };
        };
      };
    };
}
