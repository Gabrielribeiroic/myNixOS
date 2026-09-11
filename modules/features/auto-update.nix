{ self, ... }:
{
  flake.nixosModules.auto-update =
    { config, lib, pkgs, ... }:
    {
      options.features.auto-update = {
        enable = lib.mkEnableOption "nightly nixos auto-upgrade + weekly reboot + garbage collection" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.auto-update.enable {
        # Bootstrapped and refreshed only from reviewed repository content during
        # controlled deployments; never synchronized automatically from Syncthing.
        # allowReboot stays false: reboots are handled by the weekly timer below.
        system.autoUpgrade = {
          enable = true;
          flake = "path:/var/lib/homelab-config";
          operation = "switch";
          dates = "04:00";
          allowReboot = false;
        };

        # Unconditional weekly reboot (Mon 01:00 local, America/Recife) so
        # kernel/systemd updates actually take effect. Independent of
        # autoUpgrade.allowReboot on purpose.
        systemd.timers.weekly-reboot = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "Mon *-*-* 01:00:00 America/Recife";
            Persistent = true;
          };
        };
        systemd.services.weekly-reboot = {
          description = "Weekly unconditional reboot";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/shutdown -r now";
            User = "root";
          };
        };

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      };
    };
}
