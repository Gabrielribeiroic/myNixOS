{ self, ... }: {
  flake.nixosModules.n8n =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.sops.secrets)
        n8n_db_password
        n8n_encryption_key
        n8n_runners_auth_token
        cloudflare_tunnel_token
        ;

      n8nEnvironment = {
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_HOST = "127.0.0.1";
        DB_POSTGRESDB_PORT = "5432";
        DB_POSTGRESDB_DATABASE = "n8n";
        DB_POSTGRESDB_USER = "n8n";
        EXECUTIONS_MODE = "queue";
        EXECUTIONS_DATA_PRUNE = "true";
        EXECUTIONS_DATA_MAX_AGE = "168";
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        N8N_HOST = "n8n.zephiron.uk";
        N8N_PROTOCOL = "https";
        N8N_EDITOR_BASE_URL = "https://n8n.zephiron.uk";
        N8N_PROXY_HOPS = "1";
        WEBHOOK_URL = "https://n8n.zephiron.uk";
        QUEUE_BULL_REDIS_HOST = "127.0.0.1";
        QUEUE_BULL_REDIS_PORT = "6379";
      };
    in
    {
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "n8n"
          "n8n-task-runner-launcher"
        ];

      sops.secrets = {
        n8n_db_password.sopsFile = ../../secrets/n8n.yaml;
        n8n_encryption_key.sopsFile = ../../secrets/n8n.yaml;
        n8n_runners_auth_token.sopsFile = ../../secrets/n8n.yaml;
        cloudflare_tunnel_token = {
          sopsFile = ../../secrets/n8n.yaml;
          restartUnits = [ "cloudflared-n8n.service" ];
        };
      };

      services = {
        n8n = {
          enable = true;
          environment = n8nEnvironment // {
            DB_POSTGRESDB_PASSWORD_FILE = n8n_db_password.path;
            N8N_ENCRYPTION_KEY_FILE = n8n_encryption_key.path;
            N8N_RUNNERS_AUTH_TOKEN_FILE = n8n_runners_auth_token.path;
          };
          taskRunners = {
            enable = true;
            runners.python.enable = false;
          };
        };

        postgresql = {
          enable = true;
          ensureDatabases = [ "n8n" ];
          ensureUsers = [
            {
              name = "n8n";
              ensureDBOwnership = true;
            }
          ];
          settings = {
            password_encryption = "scram-sha-256";
          };
          authentication = ''
            local all all peer
            host n8n n8n 127.0.0.1/32 scram-sha-256
            host n8n n8n ::1/128 scram-sha-256
          '';
        };

        redis.servers.n8n = {
          enable = true;
          port = 6379;
          bind = "127.0.0.1";
        };

        traefik = {
          enable = true;
          staticConfigOptions.entryPoints.web.address = "127.0.0.1:8080";
          dynamicConfigOptions.http = {
            routers.n8n = {
              entryPoints = [ "web" ];
              rule = "Host(`n8n.zephiron.uk`)";
              service = "n8n";
            };
            services.n8n.loadBalancer.servers = [
              { url = "http://127.0.0.1:5678"; }
            ];
          };
        };
      };

      systemd.services.n8n-postgresql-password = {
        description = "Set the n8n PostgreSQL password";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        before = [
          "n8n.service"
          "n8n-worker.service"
        ];
        requiredBy = [
          "n8n.service"
          "n8n-worker.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          LoadCredential = [ "n8n_db_password:${n8n_db_password.path}" ];
        };
        script = ''
          password="$(<"$CREDENTIALS_DIRECTORY/n8n_db_password")"
          ${lib.getExe' pkgs.postgresql "psql"} --dbname=postgres --set=role_password="$password" <<'SQL'
          ALTER ROLE n8n PASSWORD :'role_password';
          SQL
        '';
      };

      # The dashboard-managed tunnel accepts a token file, keeping the bearer
      # token out of both the Nix store and the process command line.
      systemd.services.cloudflared-n8n = {
        description = "Cloudflare Tunnel for n8n";
        after = [
          "network-online.target"
          "traefik.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "traefik.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          DynamicUser = true;
          LoadCredential = [
            "cloudflare_tunnel_token:${cloudflare_tunnel_token.path}"
          ];
          ExecStart = "${lib.getExe pkgs.cloudflared} tunnel --no-autoupdate --metrics 127.0.0.1:20241 run --token-file %d/cloudflare_tunnel_token --url http://127.0.0.1:8080";
          Restart = "on-failure";
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

      systemd.services.n8n-worker = {
        description = "n8n queue worker";
        after = [
          "n8n.service"
          "redis-n8n.service"
          "n8n-postgresql-password.service"
        ];
        requires = [
          "n8n.service"
          "redis-n8n.service"
          "n8n-postgresql-password.service"
        ];
        wantedBy = [ "multi-user.target" ];
        partOf = [ "n8n.service" ];
        environment = n8nEnvironment // {
          N8N_USER_FOLDER = "/var/lib/n8n-worker";
          N8N_RUNNERS_MODE = "external";
          # Queue workers still start a broker; keep it separate from the
          # main process broker used by the external task-runner service.
          N8N_RUNNERS_BROKER_PORT = "5689";
          DB_POSTGRESDB_PASSWORD_FILE = "%d/n8n_db_password";
          N8N_ENCRYPTION_KEY_FILE = "%d/n8n_encryption_key";
          N8N_RUNNERS_AUTH_TOKEN_FILE = "%d/n8n_runners_auth_token";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${lib.getExe config.services.n8n.package} worker";
          Restart = "on-failure";
          StateDirectory = "n8n-worker";
          DynamicUser = true;
          LoadCredential = [
            "n8n_db_password:${n8n_db_password.path}"
            "n8n_encryption_key:${n8n_encryption_key.path}"
            "n8n_runners_auth_token:${n8n_runners_auth_token.path}"
          ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          MemoryDenyWriteExecute = false;
          LockPersonality = true;
        };
      };
    };
}
