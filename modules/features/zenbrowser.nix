{ self, inputs, ... }: {

  flake.nixosModules.zenbrowser = { pkgs, ... }: {
    home-manager.users.zep = { pkgs, ... }: {
      
      home.packages = [
        inputs.zen-browser.packages.${pkgs.system}.default
      ];

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "zen.desktop";
          "x-scheme-handler/http" = "zen.desktop";
          "x-scheme-handler/https" = "zen.desktop";
          "application/x-extension-htm" = "zen.desktop";
          "application/x-extension-html" = "zen.desktop";
          "application/x-extension-shtml" = "zen.desktop";
          "application/xhtml+xml" = "zen.desktop";
          "application/x-openurl" = "zen.desktop";
        };
      };

    };
  };
}
