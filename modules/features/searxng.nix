{ self, ... }: {
  flake.nixosModules.searxng =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.sops.secrets) searxng_secret_key;
    in
    {
      options.features.searxng = {
        enable = lib.mkEnableOption "SearXNG metasearch engine" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.searxng.enable {
        services.searx = {
          enable = true;
          package = pkgs.searxng;
          redisCreateLocally = true;

          settings = {
            general = {
              debug = false;
              instance_name = "SearXNG";
              donation_url = false;
              contact_url = false;
            };
            ui = {
              default_locale = "pt_BR";
              default_theme = "simple";
              theme_args.simple_style = "auto";
              hotkeys = "vim";
            };
            search = {
              safe_search = 2;
              autocomplete = "duckduckgo";
            };
            server = {
              port = 8888;
              bind_address = "127.0.0.1";
              secret_key = searxng_secret_key.path;
              limiter = false;
              public_instance = false;
              image_proxy = true;
              method = "GET";
            };
            outgoing = {
              request_timeout = 5.0;
              enable_http2 = true;
            };
          };
        };

        networking.firewall.allowedTCPPorts = [ 8888 ];
      };
    };
}
