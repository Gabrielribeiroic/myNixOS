{ self, inputs, ... }: {

  flake.nixosModules.gnome = { config, pkgs, lib, ... }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];

    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    services.xserver.xkb = {
      layout = "us";
      variant = "alt-intl";
    };

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      epiphany
      geary
      totem
    ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    
    home-manager.users.zep = { pkgs, config, ... }: {
      home.stateVersion = "26.05"; 

      dconf.settings = {

        "org/gnome/desktop/background" = {
          picture-uri = "file://${../../assets/wallpapers/sunset.jpg}";
          picture-uri-dark = "file://${../../assets/wallpapers/sunset.jpg}";
          picture-options = "zoom";
        };

        "org/gnome/desktop/screensaver" = {
          picture-uri = "file://${../../assets/wallpapers/sunset.jpg}";
          lock-enabled = false;
          idle-activation-enabled = false;
        }; 

        "org/gnome/shell/keybindings" = {
          toggle-application-view = [ "<Super>d" ];

          show-screenshot-ui = [ "<Super><Shift>s" "print" ];

          switch-to-application-1 = [];
          switch-to-application-2 = [];
          switch-to-application-3 = [];
          switch-to-application-4 = [];
          switch-to-application-5 = [];
          switch-to-application-6 = [];
          switch-to-application-7 = [];
          switch-to-application-8 = [];
          switch-to-application-9 = [];
        };

        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = false;
          show-battery-percentage = true;
        };

        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super><Shift>q" "<Alt>F4" ];
          maximize = [ "<Super>f" ];
          unmaximize = [ "<Super><Shift>f" ];
          switch-to-workspace-left = [ "<Super>Left" "<Super>h" ];
          switch-to-workspace-right = [ "<Super>Right" "<Super>l" ];
          move-to-workspace-left = [ "<Super><Shift>Left" "<Super><Shift>h" ];
          move-to-workspace-right = [ "<Super><Shift>Right" "<Super><Shift>l" ];

          switch-to-workspace-1 = [ "<Super>1" ];
          switch-to-workspace-2 = [ "<Super>2" ];
          switch-to-workspace-3 = [ "<Super>3" ];
          switch-to-workspace-4 = [ "<Super>4" ];
          switch-to-workspace-5 = [ "<Super>5" ];
          switch-to-workspace-7 = [ "<Super>7" ];
          switch-to-workspace-8 = [ "<Super>8" ];
          switch-to-workspace-9 = [ "<Super>9" ];

          move-to-workspace-1 = [ "<Super><Shift>1" ];
          move-to-workspace-2 = [ "<Super><Shift>2" ];
          move-to-workspace-3 = [ "<Super><Shift>3" ];
          move-to-workspace-4 = [ "<Super><Shift>4" ];
          move-to-workspace-5 = [ "<Super><Shift>5" ];
          move-to-workspace-6 = [ "<Super><Shift>6" ];
          move-to-workspace-7 = [ "<Super><Shift>7" ];
          move-to-workspace-8 = [ "<Super><Shift>8" ];
          move-to-workspace-9 = [ "<Super><Shift>9" ];
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Terminal (Kitty)";
          command = "${pkgs.lib.getExe pkgs.kitty}";
          binding = "<Super>Return";
        };

        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 0;
        };

        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          idle-dim = false;
          sleep-inactive-ac-timeout = 0;
        };
      };
    };
  };
}
