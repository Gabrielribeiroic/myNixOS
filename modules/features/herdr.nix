{ self, ... }:
{
  flake.nixosModules.herdr =
    { config, lib, pkgs, ... }:
    {
      options.features.herdr = {
        enable = lib.mkEnableOption "herdr terminal workspace manager server (headless, user service)" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.herdr.enable {
        home-manager.users.zep = { pkgs, ... }: {
          home.packages = [ pkgs.herdr ];

          systemd.user.services.herdr = {
            Unit = {
              Description = "herdr terminal workspace manager server";
            };
            Service = {
              ExecStart = "${pkgs.herdr}/bin/herdr server";
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          # HM owns ONLY this file; herdr state (session.json, logs, sockets)
          # lives alongside it in ~/.config/herdr/ and is left alone.
          # herdr reads config at startup and does not rewrite it at runtime.
          xdg.configFile."herdr/config.toml".text = ''
            onboarding = false

            [terminal]
            default_shell = "fish"
            shell_mode = "login"

            [update]
            version_check = false
            manifest_check = false
          '';
        };

        # Upstream issue #3324: the default user slice TasksMax (512) kills the
        # server. 1000 is zep's uid on the homelab.
        systemd.slices."user-1000".sliceConfig.TasksMax = 2048;

        users.users.zep.linger = true;
      };
    };
}
