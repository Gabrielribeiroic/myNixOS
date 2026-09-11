{ ... }:
{
  flake.nixosModules.pawns-app =
    { config, lib, pkgs, ... }:
    {
      options.features.pawns-app.enable = lib.mkEnableOption "Pawns.app bandwidth-sharing client" // {
        default = false;
      };

      config = lib.mkIf config.features.pawns-app.enable {
        virtualisation.docker.enable = true;

        # Official install guide:
        # https://pawns.app/blog/how-to-install-and-run-the-pawns-app-container-in-docker/
        # It specifies iproyal/pawns-cli and -email, -password,
        # -device-name, -device-id, and -accept-tos arguments. The guide does
        # not specify environment variables, a volume, host networking, or a
        # published port. The registry's current version tag is pinned below
        # by its immutable multi-architecture manifest digest.
        systemd.services.pawns-app = {
          description = "Pawns.app bandwidth-sharing container";
          wantedBy = [ "multi-user.target" ];
          after = [ "docker.service" "network-online.target" ];
          wants = [ "network-online.target" ];
          requires = [ "docker.service" ];
          serviceConfig = {
            Type = "simple";
            User = "root";
            StateDirectory = "pawns-app";
            LoadCredential = [
              "email:${config.sops.secrets."pawns-app-email".path}"
              "password:${config.sops.secrets."pawns-app-password".path}"
            ];
            # Pawns' documented interface accepts credentials only as CLI
            # arguments. LoadCredential keeps them out of the Nix store and
            # unit file, but Docker necessarily receives them in argv.
            ExecStartPre = "-${pkgs.docker}/bin/docker rm -f pawns-app";
            # The official guide documents no volume, state directory,
            # host-network mode, or published port. Docker's container
            # metadata is therefore the only documented persistent state.
            ExecStart = pkgs.writeShellScript "pawns-app-start" ''
              set -eu
              read -r email < "$CREDENTIALS_DIRECTORY/email"
              read -r password < "$CREDENTIALS_DIRECTORY/password"
              exec ${pkgs.docker}/bin/docker run \
                --name pawns-app \
                --restart=no \
                iproyal/pawns-cli:0.36.6@sha256:e64850a9187e93e784fd355e20b921e052687fc5b4357dd09a8b770e47fd0437 \
                "-email=$email" \
                "-password=$password" \
                -device-name=homelab \
                -device-id=homelab \
                -accept-tos
            '';
            ExecStop = "${pkgs.docker}/bin/docker stop pawns-app";
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
          };
        };
      };
    };
}
