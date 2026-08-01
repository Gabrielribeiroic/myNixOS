{ self, inputs, ... }: {

  flake.nixosModules.gh = { pkgs, ... }: {
    home-manager.users.zep = { pkgs, ... }: {
      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "https";
          prompt = "enabled";
        };
      };

      programs.git.settings = {
        enable = true;
        userName = "Gabriel Ribeiro";
        userEmail = "ic.gabrielribeiro@gmail.com";
        init.defaultBranch = "main";
        url."git@github.com:".insteadOf = "https://github.com/";
      };
    };
  };
}
