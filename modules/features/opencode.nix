{ self, ... }:
{
  flake.nixosModules.opencode =
    { config, lib, pkgs, ... }:
    {
      options.features.opencode = {
        enable = lib.mkEnableOption "OpenCode AI coding agent (package only)" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.opencode.enable {
        home-manager.users.zep = { pkgs, ... }: {
          # Package only, deliberately NOT programs.opencode.enable: HM's
          # opencode module is inert without settings, but ~/.config/opencode is
          # owned by Syncthing on this host — HM must never write into it.
          home.packages = [ pkgs.opencode ];
        };
      };
    };
}
