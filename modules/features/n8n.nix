{ self, ... }: {
  flake.nixosModules.n8n =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.sops.secrets) n8n_db_password n8n_encryption_key;

      n8nEnvironment = {
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_HOST = "127.0.0.1";
        DB_POSTGRESDB_PORT = 5432;
        DB_POSTGRESDB_DATABASE = "n8n";
        DB_POSTGRESDB_USER = "n8n";
        EXECUTIONS_MODE = "queue";
        EXECUTIONS_DATA_PRUNE = true;
        EXECUTIONS_DATA_MAX_AGE = 168;
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        QUEUE_BULL_REDIS_HOST = "127.0.0.1";
        QUEUE_BULL_REDIS_PORT = 6379;
      };
    in
    {
      nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "n8n";

      sops.secrets = {
        n8n_db_password.sopsFile = ../../secrets/n8n.yaml;
        n8n_encryption_key.sopsFile = ../../secrets/n8n.yaml;
      };

      services = {
        n8n = {
          enable = true;
          environment = n8nEnvironment // {
            DB_POSTGRESDB_PASSWORD_FILE = n8n_db_password.path;
            N8N_ENCRYPTION_KEY_FILE = n8n_encryption_key.path;
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
      };

      # PostgreSQL's declarative user setup cannot read a SOPS secret, so set
      # the local-only n8n role password through a systemd credential.
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
          ${lib.getExe' pkgs.postgresql "psql"} --dbname=postgres --set=role_password="$password" --command "ALTER ROLE n8n PASSWORD :'role_password';"
        '';
      };

      # Queue workers are not the module's Code-node task runners. They are
      # native n8n processes backed by the same PostgreSQL and Redis services.
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
          DB_POSTGRESDB_PASSWORD_FILE = "%d/n8n_db_password";
          N8N_ENCRYPTION_KEY_FILE = "%d/n8n_encryption_key";
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
