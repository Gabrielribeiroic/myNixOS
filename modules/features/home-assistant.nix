{ self, ... }: {
  flake.nixosModules.home-assistant =
    { config, lib, pkgs, ... }:
    {
      options.features.home-assistant = {
        enable = lib.mkEnableOption "Home Assistant home automation server" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.home-assistant.enable {
        services.home-assistant = {
          enable = true;
          # Nix owns the declarative baseline configuration.yaml; device
          # integrations/credentials are provisioned through the HA config
          # flow and persist in /var/lib/hass/.storage across rebuilds.
          configWritable = false;
          config = {
            mobile_app = {};
            homeassistant = {
              name = "Homelab";
              unit_system = "metric";
              time_zone = "America/Recife";
            };
            http.server_port = 8123;
            automation = "!include automations.yaml";
          };
          # The option default (default_config, met, esphome) is replaced by
          # any definition, so list it explicitly and add Tapo support.
          extraComponents = [ "default_config" "met" "esphome" "tplink" "mobile_app" ];
          # Local (cloud-free) Tuya integration for non-relay devices.
          customComponents = with pkgs.home-assistant-custom-components; [
            tuya_local
          ];
          # openFirewall stays false (default): the homelab trusts tailscale0,
          # so the UI is reachable over Tailscale without a global port rule.
        };
      };
    };
}
